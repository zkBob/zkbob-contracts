// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {PriorityQueue, PriorityOperation} from "./PriorityQueue.sol";
import {ZkBobPool} from "../ZkBobPool.sol";
import {MemoUtils} from "./MemoUtils.sol";

contract ZkBobSequencer {
    using PriorityQueue for PriorityQueue.Queue;

    event Commited(); // TODO: Fill the data
    event Proved();
    event Rejected();
    event Skipped();


    PriorityQueue.Queue priorityQueue;
    ZkBobPool pool;
    mapping(address => uint256) accumulatedFees;
    uint256 lastQueueUpdateTimestamp;

    uint256 constant TRANSFER_DELTA_SIZE = 28;
    bytes4 internal constant MESSAGE_PREFIX_COMMON_V1 = 0x00000000; // TODO: import it?
    uint256 constant R = 21888242871839275222246405745257275088548364400416034343698204186575808495617; // TODO: import it?

    // TODO: make it configurable
    uint256 constant EXPIRATION_TIME = 1 hours;
    uint256 constant PROXY_GRACE_PERIOD = 10 minutes;

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

    // 1. Verify that commit data is valid
    //  1) msg.sender == proxy that is fixed in the memo
    //  2) Nullifier is not spent
    //  3) Index is not too high (this index is used to get used root from the pool)
    //  4) Transfer proof is correct according to the current pool state
    //  5) Memo version is ok
    // 2. Save operation in the priority queue (only commit data hash and timestamp)
    // 3. Emit event
    function commit(CommitData calldata commitData) external {
        (address proxy, , ) = MemoUtils.parseFees(commitData.memo);
        require(msg.sender == proxy, "ZkBobSequencer: not authorized");

        require(pool.nullifiers(commitData.nullifier) == 0, "ZkBobSequencer: nullifier is spent");
        require(uint96(commitData.index) <= pool.pool_index(), "ZkBobSequencer: index is too high");
        require(pool.transfer_verifier().verifyProof(transfer_pub(commitData), commitData.transfer_proof), "ZkBobSequencer: invalid proof");
        require(MemoUtils.parseMessagePrefix(commitData.memo) == MESSAGE_PREFIX_COMMON_V1, "ZkBobPool: bad message prefix");
        
        PriorityOperation memory op = PriorityOperation(commitHash(commitData), block.timestamp);
        priorityQueue.pushBack(op);

        // We can also save pending nullifier

        emit Commited();
    }

    // 1. Pop first operation from priority queue
    // 2. Verify that:
    //  1) If we are in the grace period then msg.sender can be only proxy, otherwice it can be anyone
    //  2) Provided commitData corresponds to saved commitHash
    //  3) Tree proof is correct according to the current pool state
    //  If this checks hold then the prover did everything correctly and if the pool.transact will revert we can safely remove this operation from the queue
    // 3. Call pool.transact with the provided data
    //  1) If call is successfull we store fees and emit event
    //  2) If call is not successfull we only emit event. Important: we don't revert
    function prove(CommitData calldata commitData, ProveData calldata proveData) external {
        PriorityOperation memory op = priorityQueue.popFront();
        require(op.commitHash == commitHash(commitData), "ZkBobSequencer: invalid commit hash");

        // We need to store proxy address in the memo to prevent front running during commit
        (address proxy, uint256 proxy_fee, uint256 prover_fee) = MemoUtils.parseFees(commitData.memo);
        uint256 timestamp = max(op.timestamp, lastQueueUpdateTimestamp);
        if (block.timestamp <= timestamp + PROXY_GRACE_PERIOD) {
            require(msg.sender == proxy, "ZkBobSequencer: not authorized");
        }
        // We can introduce some scheme to pick one of the previous prover to aboid race condition
        
        // We check proofs twice with the current implementation.
        // It should be possible to avoid it but we need to modify pool contract.
        require(pool.tree_verifier().verifyProof(tree_pub(commitData, proveData), proveData.tree_proof), "ZkBobSequencer: invalid proof");

        uint256 accumulatedFeeBefore = pool.accumulatedFee(address(this));
        bool success = propogateToPool(commitData, proveData);
        lastQueueUpdateTimestamp = block.timestamp;

        // We remove the commitment from the queue regardless of the result of the call to pool contract
        // If we check that the prover is not malicious then the tx is not valid because of the limits or
        // absence of funds so it can't be proved
        if (success) {
            // We need to store fees and add ability to withdraw them
            uint256 fee = pool.accumulatedFee(address(this)) - accumulatedFeeBefore;

            require(proxy_fee + prover_fee <= fee, "ZkBobSequencer: fee is too low");
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
    function skip() external {
        PriorityOperation memory op = priorityQueue.popFront();
        require(op.timestamp + EXPIRATION_TIME < block.timestamp, "ZkBobSequencer: not expired yet");
        lastQueueUpdateTimestamp = block.timestamp;
        emit Skipped();
    }

    function withdrawFees() external {
        // TODO
    }


    function commitHash(CommitData calldata commitData) internal pure returns (bytes32) {
        return keccak256(abi.encode(commitData));
    }

    function transfer_pub(CommitData calldata commitData) internal view returns (uint256[5] memory r) {
        r[0] = pool.roots(commitData.index);
        r[1] = commitData.nullifier;
        r[2] = commitData.out_commit;
        r[3] = commitData.transfer_delta + (pool.pool_id() << (TRANSFER_DELTA_SIZE * 8));
        r[4] = uint256(keccak256(commitData.memo)) % R;
    }

    function tree_pub(CommitData calldata commitData, ProveData calldata proveData) internal view returns (uint256[3] memory r) {
        r[0] = pool.roots(pool.pool_index());
        r[1] = proveData.root_after;
        r[2] = commitData.out_commit;
    }

    function preparePoolTx(CommitData calldata commitData, ProveData calldata proveData) internal pure returns (bytes memory) {
        // TODO: fix it
        return abi.encode(commitData, proveData);
    }

    function propogateToPool(CommitData calldata commitData, ProveData calldata proveData) internal returns (bool) {
        // Call pool.transact
        return false;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256 maxValue) {
        maxValue = a;
        if (b > a) {
            maxValue = b;
        }
    }
}