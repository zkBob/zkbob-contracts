pragma solidity ^0.8.15;
import "forge-std/Test.sol";
import "../../src/zkbob/utils/PriorityQueue.sol";
import "forge-std/console.sol";

contract DummyQueue {
    using PriorityQueue for PriorityQueue.Queue;

    PriorityQueue.Queue _queue;
    address immutable prover1 = address(bytes20(new bytes(20)));

    function list() external view returns (PriorityOperation[] memory) {
        return _queue.list();
    }

    function pushBack(PriorityOperation memory _operation) external {
        _queue.pushBack(_operation);
    }

    function head() external view returns (uint256) {
        return _queue.head;
    }

    function tail() external view returns (uint256) {
        return _queue.tail;
    }

    function popFront() external returns (PriorityOperation memory priorityOperation) {
        return _queue.popFront();
    }
}

contract PriorityQueueTest is Test {
    using PriorityQueue for PriorityQueue.Queue;

    address immutable prover1 = makeAddr("Prover #1");
    DummyQueue _queueContract;

    function setUp() external {
        _queueContract = new DummyQueue();
    }

    function newOp(
        uint256 id
    ) external view returns (PriorityOperation memory) {
        return PriorityOperation(id, prover1, uint64(0), uint64(0));
    }

    function testEmptyQueue() external {
        PriorityOperation[] memory ops = _queueContract.list();
        assertEq(0, ops.length);
    }

    function testPushBack() external {
        _queueContract.pushBack(this.newOp(0));

        assertEq(0, _queueContract.head());
        assertEq(1, _queueContract.tail());

        assertEq(1, _queueContract.list().length);

        _queueContract.pushBack(this.newOp(2));

        assertEq(2, _queueContract.list().length);
    }
    function testPopFront() external {
        _queueContract.pushBack(this.newOp(0));
        _queueContract.pushBack(this.newOp(1));
        _queueContract.pushBack(this.newOp(2));

        assertEq(0, _queueContract.head());
        assertEq(3, _queueContract.tail());

        PriorityOperation memory first = _queueContract.popFront();

        assertEq(first.commitment, uint256(0));

        assertEq(1, _queueContract.head());
        assertEq(3, _queueContract.tail());

        assertEq(2, _queueContract.list().length);
    }
}
