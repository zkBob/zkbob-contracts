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

    uint256 constant TRANSFER_DELTA_SIZE = 28;
    bytes4 internal constant MESSAGE_PREFIX_COMMON_V1 = 0x00000000;
    // TODO: make it configurable
    uint256 public constant EXPIRATION_TIME = 1 hours;
    uint256 public constant PROXY_GRACE_PERIOD = 10 minutes;

    // Queue of operations
    PriorityQueue.Queue priorityQueue;
    
    // Pool contract, this contract is operator of the pool
    ZkBobPool _pool;

    // Accumulated fees for each prover
    mapping(address => uint256) public accumulatedFees;

    // Last time when queue was updated
    uint256 lastQueueUpdateTimestamp;

    mapping(uint256 => bool) pendingNullifiers;

    event Commited(); // TODO: Fill the data
    event Proved();
    event Rejected();
    event Skipped();

    constructor(address pool) {
        _pool = ZkBobPool(pool);
    }

    // Possible problems here:
    // 1. Malicious user can front run a prover and the prover spend some gas without any result
    function commit() external {
        (
            uint256 nullifier,
            uint256 outCommit,
            uint48 index,
            uint256 transferDelta,
            ,
            uint256[8] calldata transferProof,
            uint16 txType,
            bytes calldata memo
        ) = _parseCommitData();

        (address proxy, , ) = MemoUtils.parseFees(memo);
        
        require(pendingNullifiers[nullifier] == false, "ZkBobSequencer: nullifier is already pending");
        require(_pool.nullifiers(nullifier) == 0, "ZkBobSequencer: nullifier is spent");
        require(msg.sender == proxy, "ZkBobSequencer: not authorized");
        require(uint96(index) <= _pool.pool_index(), "ZkBobSequencer: index is too high");
        require(_pool.transfer_verifier().verifyProof(transfer_pub(index, nullifier, outCommit, transferDelta, memo), transferProof), "ZkBobSequencer: invalid proof");
        require(MemoUtils.parseMessagePrefix(memo, txType) == MESSAGE_PREFIX_COMMON_V1, "ZkBobPool: bad message prefix");
        
        // TODO: special case for deposits, we need to claim fee here

        bytes32 hash = commitHash(nullifier, outCommit, transferDelta, transferProof, memo);
        PriorityOperation memory op = PriorityOperation(hash, nullifier, block.timestamp);
        priorityQueue.pushBack(op);
        pendingNullifiers[nullifier] = true;

        emit Commited();
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
        PriorityOperation memory op = popFirstUnexpiredOperation();

        uint256 nullifier = _transfer_nullifier();
        uint48 index = _transfer_index();
        bytes calldata memo = _memo_data();
        uint256[8] calldata transferProof = _transfer_proof();

        require(
            op.commitHash == commitHash(nullifier, _transfer_out_commit(), _transfer_delta(), transferProof, memo),
            "ZkBobSequencer: invalid commit hash"
        );

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

        lastQueueUpdateTimestamp = block.timestamp;
        delete pendingNullifiers[nullifier];

        uint256 accumulatedFeeBefore = _pool.accumulatedFee(address(this));
        bool success = propagateToPool();

        // We remove the commitment from the queue regardless of the result of the call to pool contract
        // If we check that the prover is not malicious then the tx is not valid because of the limits or
        // absence of funds so it can't be proved
        if (success) {
            // We need to store fees and add ability to withdraw them
            uint256 fee = _pool.accumulatedFee(address(this)) -
                accumulatedFeeBefore;
            require(
                proxy_fee + prover_fee == fee,
                "ZkBobSequencer: fee is not correct"
            );
            accumulatedFees[proxy] += proxy_fee;
            accumulatedFees[msg.sender] += prover_fee;

            emit Proved();
        } else {
            emit Rejected();
        }
    }

    function withdrawFees() external {
        uint256 fee = accumulatedFees[msg.sender];
        require(fee > 0, "ZkBobSequencer: no fees to withdraw");
        accumulatedFees[msg.sender] = 0;
        _pool.withdrawFeePartial(address(this), msg.sender, fee);
    }

    function _root() override internal view  returns (uint256){
        return _pool.roots(_pool.pool_index());
    }

    function _pool_id() override internal view returns (uint256){
        return _pool.pool_id();
    }

    function popFirstUnexpiredOperation() internal returns (PriorityOperation memory) {
        PriorityOperation memory op = priorityQueue.popFront();
        uint256 timestamp = max(op.timestamp, lastQueueUpdateTimestamp);
        while (timestamp + EXPIRATION_TIME < block.timestamp) {
            delete pendingNullifiers[op.nullifier];
            // TODO: is is correct?
            lastQueueUpdateTimestamp = op.timestamp + EXPIRATION_TIME;
            op = priorityQueue.popFront();
            timestamp = max(op.timestamp, lastQueueUpdateTimestamp);
        }
        return op;
    }
    
    function commitHash(
        uint256 nullifier,
        uint256 out_commit,
        uint256 transfer_delta,
        uint256[8] calldata transfer_proof,
        bytes calldata memo
    ) internal pure returns (bytes32) {
        // TODO: check that it is enough
        return keccak256(abi.encodePacked(nullifier, out_commit, transfer_delta, transfer_proof, memo));
    }

    function transfer_pub(
        uint48 index, 
        uint256 nullifier, 
        uint256 outCommit, 
        uint256 transferDelta, 
        bytes calldata memo
    ) internal view returns (uint256[5] memory r) {
        r[0] = _pool.roots(index);
        r[1] = nullifier;
        r[2] = outCommit;
        r[3] = transferDelta + (_pool.pool_id() << (TRANSFER_DELTA_SIZE * 8));
        r[4] = uint256(keccak256(memo)) % R;
    }

    function propagateToPool() internal returns (bool success) {
        address poolAddress = address(_pool);
        bytes4 selector = ZkBobPool.transact.selector;
        bytes memory data = new bytes(msg.data.length);
        assembly {
            // TODO: check it
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

    function pendingOperation() external view returns (PriorityOperation memory op) {
        require(!priorityQueue.isEmpty(), "ZkBobSequencer: queue is empty");
        
        uint256 head = priorityQueue.getFirstUnprocessedPriorityTx();
        uint256 tail = priorityQueue.getTotalPriorityTxs();
        bool found = false;
        for (uint256 i = head; i <= tail; i++) {
            if (op.timestamp + EXPIRATION_TIME >= block.timestamp) {
                op = priorityQueue.get(i);
                found = true;
                break;
            }
        }
        require(found, "ZkBobSequencer: no pending operations");
    }
}