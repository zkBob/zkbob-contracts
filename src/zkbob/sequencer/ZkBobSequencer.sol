// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {PriorityQueue, PriorityOperation} from "./PriorityQueue.sol";
import {ZkBobPool} from "../ZkBobPool.sol";
import {MemoUtils} from "./MemoUtils.sol";
import {CustomABIDecoder} from "../utils/CustomABIDecoder.sol";
import {Parameters} from "../utils/Parameters.sol";
import "forge-std/console.sol";

contract ZkBobSequencer is CustomABIDecoder, Parameters, MemoUtils {
    using PriorityQueue for PriorityQueue.Queue;

    constructor(address pool) {
        _pool = ZkBobPool(pool);
    }

    struct CommitData {
        uint48 index;
        uint256 out_commit;
        uint256 nullifier;
        uint256 transfer_delta;
        bytes memo;
        uint256[8] transfer_proof;
    }

    struct ProveData {
        uint256 root_after;
        uint256[8] tree_proof;
    }

    event Commited(); // TODO: Fill the data
    event Proved();
    event Rejected();
    event Skipped();

    uint256 constant TRANSFER_DELTA_SIZE = 28;
    bytes4 internal constant MESSAGE_PREFIX_COMMON_V1 = 0x00000000;
    // TODO: make it configurable
    uint256 constant EXPIRATION_TIME = 1 hours;
    uint256 constant PROXY_GRACE_PERIOD = 10 minutes;

    // Queue of operations
    PriorityQueue.Queue priorityQueue;
    
    // Pool contract, this contract is operator of the pool
    ZkBobPool _pool;

    // Accumulated fees for each prover
    mapping(address => uint256) accumulatedFees;

    // Last time when queue was updated
    uint256 lastQueueUpdateTimestamp;

    mapping(uint256 => uint256) pendingNullifiers;

    function _root() override internal view  returns (uint256){
        return _pool.roots(_pool.pool_index());
    }
    function _pool_id() override internal view returns (uint256){
        return _pool.pool_id();
    }

    // 1. Verify that commit data is valid
    //  1) nullifier is not pending
    //  2) msg.sender == proxy that is fixed in the memo
    //  3) Nullifier is not spent
    //  4) Index is not too high (this index is used to get used root from the pool)
    //  5) Transfer proof is correct according to the current pool state
    //  6) Memo version is ok
    // 2. Save operation in the priority queue (only commit data hash and timestamp)
    // 3. Save pending nullifier
    // 4. Emit event
    // Possible problems here:
    // 1. Malicious user can front run a prover and the prover spend some gas without any result
    function commit() external {
        (
            uint256 nullifier,
            uint256 outCommit,
            uint48 index,
            uint256 transferDelta,
            int64 tokenAmount,
            uint256[8] calldata transferProof,
            uint16 txType,
            bytes calldata memo
        ) = _parseCommitData();
        
        require(pendingNullifiers[nullifier] == 0, "ZkBobSequencer: nullifier is already pending");

        (address proxy, , ) = MemoUtils.parseFees(memo);
        require(msg.sender == proxy, "ZkBobSequencer: not authorized");

        require(_pool.nullifiers(nullifier) == 0, "ZkBobSequencer: nullifier is spent");
        require(uint96(index) <= _pool.pool_index(), "ZkBobSequencer: index is too high");
        require(_pool.transfer_verifier().verifyProof(transfer_pub(index, nullifier, outCommit, transferDelta, memo), transferProof), "ZkBobSequencer: invalid proof");
        require(MemoUtils.parseMessagePrefix(memo) == MESSAGE_PREFIX_COMMON_V1, "ZkBobPool: bad message prefix");
        

        CommitData memory commitData = CommitData(
            index,
            outCommit,
            nullifier,
            transferDelta,
            memo,
            transferProof
        );
        PriorityOperation memory op = PriorityOperation(commitHash(commitData), block.timestamp);
        priorityQueue.pushBack(op);

        pendingNullifiers[nullifier] = 1;

        emit Commited();
    }

    function head() external view returns (PriorityOperation memory) {
        return priorityQueue.data[priorityQueue.head];
    }

    // 1. Pop first operation from priority queue
    // 2. Verify that:
    //  1) If we are in the grace period then msg.sender can be only proxy, otherwice it can be anyone
    //  2) Provided commitData corresponds to saved commitHash
    //  3) Tree proof is correct according to the current pool state
    //  If this checks hold then the prover did everything correctly and if the _pool.transact will revert we can safely remove this operation from the queue
    // 3. Call _pool.transact with the provided data
    //  1) If call is successfull we store fees and emit event
    //  2) If call is not successfull we only emit event. Important: we don't revert
    // 4. Update lastQueueUpdateTimestamp and delete pending nullifier
    // Possible problems here:
    // 1. If the PROXY_GRACE_PERIOD is ended then anyone can prove the operation and race condition is possible
    //    We can prevent it by implementing some mechanism to pick a prover from the previous ones
    // 2. Malicious user can commit a bad operation (low fees, problems with compliance, etc.) so there is no prover that will be ready to prove it
    //    In this case the prioirity queue will be locked until the expiration time
    function prove() external {
        PriorityOperation memory op = priorityQueue.popFront();

        uint256 nullifier = _transfer_nullifier();
        uint48 index = _transfer_index();
        bytes memory memo = _memo_data();
        uint256[8] memory transferProof = _transfer_proof();
        CommitData memory commitData = CommitData(
            index,
            _transfer_out_commit(),
            nullifier,
            _transfer_delta(),
            memo,
            transferProof
        );

        require(
            op.commitHash == commitHash(commitData),
            "ZkBobSequencer: invalid commit hash"
        );

        // We need to store proxy address in the memo to prevent front running during commit
        (address proxy, uint256 proxy_fee, uint256 prover_fee) = MemoUtils.parseFees(memo);
        uint256 timestamp = max(op.timestamp, lastQueueUpdateTimestamp);
        if (block.timestamp <= timestamp + PROXY_GRACE_PERIOD) {
            require(msg.sender == proxy, "ZkBobSequencer: not authorized");
        }

        uint256[8] memory treeProof = _tree_proof();

        // We check proofs twice with the current implementation.
        // It should be possible to avoid it but we need to modify pool contract.
        require(
            _pool.tree_verifier().verifyProof(
                _tree_pub(_pool.roots(index)),
                treeProof
            ),
            "ZkBobSequencer: invalid proof"
        );

        uint256 accumulatedFeeBefore = _pool.accumulatedFee(address(this));
        bool success = propagateToPool();

        lastQueueUpdateTimestamp = block.timestamp;
        delete pendingNullifiers[commitData.nullifier];

        // We remove the commitment from the queue regardless of the result of the call to pool contract
        // If we check that the prover is not malicious then the tx is not valid because of the limits or
        // absence of funds so it can't be proved
        if (success) {
            // We need to store fees and add ability to withdraw them
            uint256 fee = _pool.accumulatedFee(address(this)) -
                accumulatedFeeBefore;
            require(
                proxy_fee + prover_fee <= fee,
                "ZkBobSequencer: fee is too low"
            );
            // msg.sender recieves all the fee because:
            // 1. If block.timestamp <= timestamp + PROXY_GRACE_PERIOD then msg.sender == prover == proxy
            // 2. If block.timestamp > timestamp + PROXY_GRACE_PERIOD then we punish the proxy and send all the fee to the prover
            accumulatedFees[msg.sender] += proxy_fee + prover_fee;

            emit Proved();
        } else {
            emit Rejected();
        }
    }

    // If operation is expired then we can remove it from the queue
    // Possible problems here:
    // 1. There is no one who interested in calling this method
    function skip(CommitData calldata commitData) external {
        PriorityOperation memory op = priorityQueue.popFront();
        require(op.commitHash == commitHash(commitData), "ZkBobSequencer: invalid commit hash");
        require(op.timestamp + EXPIRATION_TIME < block.timestamp, "ZkBobSequencer: not expired yet");
        
        lastQueueUpdateTimestamp = block.timestamp;
        delete pendingNullifiers[commitData.nullifier];
        
        emit Skipped();
    }

    function withdrawFees() external {
        // TODO
    }


    function commitHash(CommitData memory commitData) internal pure returns (bytes32) {
        return keccak256(abi.encode(commitData));
    }

    function transfer_pub(uint48 index, uint256 nullifier, uint256 outCommit, uint256 transferDelta, bytes calldata memo) internal view returns (uint256[5] memory r) {
        r[0] = _pool.roots(index);
        r[1] = nullifier;
        r[2] = outCommit;
        r[3] = transferDelta + (_pool.pool_id() << (TRANSFER_DELTA_SIZE * 8));
        r[4] = uint256(keccak256(memo)) % R;
    }

    function tree_pub(CommitData calldata commitData, ProveData calldata proveData) internal view returns (uint256[3] memory r) {
        r[0] = _pool.roots(_pool.pool_index());
        r[1] = proveData.root_after;
        r[2] = commitData.out_commit;
    }

    function preparePoolTx(CommitData calldata commitData, ProveData calldata proveData) internal pure returns (bytes memory) {
        // TODO: fix it
        return abi.encode(commitData, proveData);
    }

    function propagateToPool() internal returns (bool success) {
        address poolAddress = address(_pool);
        bytes4 selector = ZkBobPool.transact.selector;
        bytes memory data = new bytes(msg.data.length);
        assembly {
            mstore(add(data, 32), selector)
            let length := sub(calldatasize(), 4)
            calldatacopy(add(data, 36), 4, length)
        }
        (success, ) = poolAddress.call(data);
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256 maxValue) {
        maxValue = a;
        if (b > a) {
            maxValue = b;
        }
    }
}