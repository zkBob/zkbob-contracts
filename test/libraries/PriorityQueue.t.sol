// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import {PriorityQueue, PendingCommitment} from "../../src/zkbob/utils/PriorityQueue.sol";
import "forge-std/console.sol";

contract PriorityQueueTest is Test {
    address immutable prover1 = makeAddr("Prover #1");
    DummyQueue _queue;

    function setUp() external {
        _queue = new DummyQueue();
    }

    function testEmptyQueue() external {
        assertEq(_queue.getSize(), 0);
        assertEq(_queue.isEmpty(), true);

        vm.expectRevert("ZkBobPool: queue is empty");
        _queue.popFront();

        vm.expectRevert("ZkBobPool: queue is empty");
        _queue.front();

        PendingCommitment[] memory ops = _queue.list();
        assertEq(0, ops.length);
    }

    function testPushBackPopFront() external {   
        for (uint256 i = 0; i < 100; i++) {
            _queue.pushBack(_newOp(i));

            assertEq(i, _queue.head());
            assertEq(i + 1, _queue.tail());
            assertEq(1, _queue.getSize());

            PendingCommitment memory commitment = _queue.front();
            _verifyOp(i, commitment);

            PendingCommitment[] memory ops = _queue.list();
            assertEq(1, ops.length);
            _verifyOp(i, ops[0]);

            PendingCommitment memory popped = _queue.popFront();
            _verifyOp(i, popped);
        }
    }

    function _newOp(
        uint256 id
    ) internal pure returns (PendingCommitment memory) {
        address prover = address(uint160(uint256(keccak256(abi.encodePacked("prover", id)))));
        uint64 fee = uint64(uint256(keccak256(abi.encodePacked("fee", id))));
        uint64 timestamp = uint64(uint256(keccak256(abi.encodePacked("timestamp", id))));
        return PendingCommitment(id, prover, fee, timestamp);
    }

    function _verifyOp(
        uint256 id,
        PendingCommitment memory op
    ) internal {
        address prover = address(uint160(uint256(keccak256(abi.encodePacked("prover", id)))));
        uint64 fee = uint64(uint256(keccak256(abi.encodePacked("fee", id))));
        uint64 timestamp = uint64(uint256(keccak256(abi.encodePacked("timestamp", id))));

        assertEq(op.commitment, id);
        assertEq(op.prover, prover);
        assertEq(op.fee, fee);
        assertEq(op.timestamp, timestamp);
    }
}

/**
 * @dev Helper contract to test PriorityQueue library
 * Without this contract forge coverage doesn't work properly
 */
contract DummyQueue {
    PriorityQueue.Queue _queue;

    function list() external view returns (PendingCommitment[] memory) {
        return PriorityQueue.list(_queue);
    }

    function pushBack(PendingCommitment memory _operation) external {
        PriorityQueue.pushBack(_queue, _operation);
    }

    function head() external view returns (uint256) {
        return _queue.head;
    }

    function tail() external view returns (uint256) {
        return _queue.tail;
    }

    function getSize() external view returns (uint256) {
        return PriorityQueue.getSize(_queue);
    }

    function isEmpty() external view returns (bool) {
        return PriorityQueue.isEmpty(_queue);
    }

    function front() external view returns (PendingCommitment memory) {
        return PriorityQueue.front(_queue);
    }

    function popFront() external returns (PendingCommitment memory pendingCommitments) {
        return PriorityQueue.popFront(_queue);
    }
}