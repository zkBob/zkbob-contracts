// SPDX-License-Identifier: MIT
// Copyright (c) 2019 Matter Labs

pragma solidity ^0.8.13;

/**
 * @dev The structure that stores all information about the pending commitment.
 * @param commitment commitment value to be added in the Merkle Tree.
 * @param prover address of the prover that submitted the commitment.
 * @param fee fee reserved for the prover who will submit the tree update proof.
 * @param timestamp commitment timestamp.
 */
struct PendingCommitment {
    uint256 commitment;
    address prover;
    uint64 fee;
    uint32 timestamp;
}

/// @dev The library provides the API to interact with the priority queue container
/// @dev Order of processing operations from queue - FIFO (Fist in - first out)
library Queue {
    using Queue for CommitmentQueue;

    /// @notice Container that stores pending commitments
    /// @param data The inner mapping that saves pending commitment by its index
    /// @param head The pointer to the first unprocessed pending commitment, equal to the tail if the queue is empty
    /// @param tail The pointer to the free slot
    struct CommitmentQueue {
        mapping(uint256 => PendingCommitment) data;
        uint256 tail;
        uint256 head;
    }

    /// @return The total number of unprocessed pending commitments in a priority queue
    function getSize(CommitmentQueue storage _queue) internal view returns (uint256) {
        return uint256(_queue.tail - _queue.head);
    }

    /// @return Whether the priority queue contains no pending commitments
    function isEmpty(CommitmentQueue storage _queue) internal view returns (bool) {
        return _queue.tail == _queue.head;
    }

    /// @notice Add the pending commitment to the end of the priority queue
    function pushBack(CommitmentQueue storage _queue, PendingCommitment memory _commitment) internal {
        // Save value into the stack to avoid double reading from the storage
        uint256 tail = _queue.tail;

        _queue.data[tail] = _commitment;
        _queue.tail = tail + 1;
    }

    function list(CommitmentQueue storage _queue) internal view returns (PendingCommitment[] memory) {
        PendingCommitment[] memory result = new PendingCommitment[](_queue.getSize());
        for (uint256 index = _queue.head; index < _queue.tail; index++) {
            result[index - _queue.head] = _queue.data[index];
        }
        return result;
    }

    /// @return The first unprocessed pending commitment from the queue
    function front(CommitmentQueue storage _queue) internal view returns (PendingCommitment memory) {
        require(!_queue.isEmpty(), "ZkBobPool: queue is empty"); // priority queue is empty

        return _queue.data[_queue.head];
    }

    /// @notice Remove the first unprocessed pending commitment from the queue
    /// @return pendingCommitment that was popped from the priority queue
    function popFront(CommitmentQueue storage _queue) internal returns (PendingCommitment memory pendingCommitment) {
        require(!_queue.isEmpty(), "ZkBobPool: queue is empty"); // priority queue is empty

        // Save value into the stack to avoid double reading from the storage
        uint256 head = _queue.head;

        pendingCommitment = _queue.data[head];
        delete _queue.data[head];
        _queue.head = head + 1;
    }
}
