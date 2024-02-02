// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {AbstractZkBobPoolTestBase} from "./ZkBobPool.t.sol";
import {AllowListOperatorManager} from "../../src/zkbob/manager/AllowListOperatorManager.sol";
import {IOperatorManager} from "../../src/interfaces/IOperatorManager.sol";
import {IBatchDepositVerifier} from "../../src/interfaces/IBatchDepositVerifier.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../shared/ForkTests.t.sol";

abstract contract AbstractZkBobPoolDecentralizedTest is AbstractZkBobPoolTestBase {
    AllowListOperatorManager manager;

    address prover1 = makeAddr("Prover #1");
    address feeReceiver1 = makeAddr("Fee Receiver #1");

    address prover2 = makeAddr("Prover #2");
    address feeReceiver2 = makeAddr("Fee Receiver #2");

    address notAllowedProver = makeAddr("Not Allowed Prover");

    address[] provers = [prover1, prover2];
    address[] feeReceivers = [feeReceiver1, feeReceiver2];

    function setUp() public override {
        super.setUp();

        manager = new AllowListOperatorManager(provers, feeReceivers, true);
        pool.setOperatorManager(IOperatorManager(manager));
    }

    function testOnlyAllowedProversCanTransact() public {
        deal(token, user1, 100 ether / D);

        bytes memory data1 = _encodePermitDeposit(int256(0.5 ether / D), 0.005 ether / D, 0.005 ether / D, prover1);
        _transact(data1, prover1);

        bytes memory data2 = _encodePermitDeposit(int256(0.5 ether / D), 0.005 ether / D, 0.005 ether / D, prover2);
        _transact(data2, prover2);

        bytes memory data3 =
            _encodePermitDeposit(int256(0.5 ether / D), 0.005 ether / D, 0.005 ether / D, notAllowedProver);
        _transactExpectRevert(data3, notAllowedProver, "ZkBobPool: not an operator");

        manager.setAllowListEnabled(false);
        _transact(data3, notAllowedProver);
    }

    function testOnlyPrivilegedProverCanUpdateTreeWithinGracePeriod() public {
        bytes memory data1 = _encodePermitDeposit(int256(0.5 ether / D), 0.005 ether / D, 0.005 ether / D, prover1);
        _transact(data1, prover1);

        vm.warp(block.timestamp + pool.gracePeriod());

        _proveTreeUpdateExpectRevert(prover2, "ZkBobPool: prover is not allowed to submit the proof yet");

        _proveTreeUpdate(prover1);
    }

    function testAnyAllowedProverCanUpdateTreeAfterGracePeriod() public {
        bytes memory data1 = _encodePermitDeposit(int256(0.5 ether / D), 0.005 ether / D, 0.005 ether / D, prover1);
        _transact(data1, prover1);

        vm.warp(block.timestamp + pool.gracePeriod() + 1);

        _proveTreeUpdate(prover2);
    }

    function testNotAllowedProverCantUpdateTreeEvenAfterGracePeriod() public {
        bytes memory data1 = _encodePermitDeposit(int256(0.5 ether / D), 0.005 ether / D, 0.005 ether / D, prover1);
        _transact(data1, prover1);

        vm.warp(block.timestamp + pool.gracePeriod() + 1);

        _proveTreeUpdateExpectRevert(notAllowedProver, "ZkBobPool: not an operator");
    }

    function testGracePeriodsMayIntersect() public {
        deal(token, user1, 100 ether / D);

        bytes memory data1 = _encodePermitDeposit(int256(0.5 ether / D), 0.005 ether / D, 0.005 ether / D, prover1);
        _transact(data1, prover1);

        bytes memory data2 = _encodePermitDeposit(int256(0.5 ether / D), 0.005 ether / D, 0.005 ether / D, prover2);
        _transact(data2, prover2);

        vm.warp(block.timestamp + pool.gracePeriod());
        _proveTreeUpdate(prover1);

        vm.warp(block.timestamp + 1);
        _proveTreeUpdate(prover1);
    }

    function testFeeDistribution() public {
        bytes memory data1 = _encodePermitDeposit(int256(0.5 ether / D), 0.017 ether / D, 0.005 ether / D, prover1);
        _transact(data1, prover1);
        assertEq(pool.accumulatedFee(prover1), 0.017 ether / (D * denominator));

        vm.prank(feeReceiver1);
        pool.withdrawFee(prover1, feeReceiver1);

        vm.warp(block.timestamp + pool.gracePeriod() + 1);

        _proveTreeUpdate(prover2);
        assertEq(pool.accumulatedFee(prover2), 0.005 ether / (D * denominator));

        vm.prank(feeReceiver2);
        pool.withdrawFee(prover2, feeReceiver2);

        assertEq(pool.accumulatedFee(prover1), 0);
        assertEq(pool.accumulatedFee(prover2), 0);

        assertEq(IERC20(token).balanceOf(feeReceiver1), 0.017 ether / D);
        assertEq(IERC20(token).balanceOf(feeReceiver2), 0.005 ether / D);
        assertEq(IERC20(token).balanceOf(address(pool)), 0.5 ether / D);
        assertEq(IERC20(token).balanceOf(user1), 0.478 ether / D); // user1 has 1 ether before the deposit
    }

    function testCantSkipCommitments() public {
        bytes memory data1 = _encodePermitDeposit(int256(0.5 ether / D), 0.005 ether / D, 0.005 ether / D, prover1);
        _transact(data1, prover1);

        vm.expectRevert("ZkBobPool: commitment mismatch");
        vm.prank(prover1);
        pool.proveTreeUpdate(_randFR(), _randProof(), _randFR());
    }

    function testCantTransactIfTreeUpdateFeeIsLessThenMin() public {
        deal(token, user1, 100 ether / D);
        pool.setMinTreeUpdateFee(uint64(0.01 ether / (D * denominator)));

        bytes memory data1 = _encodePermitDeposit(int256(0.5 ether / D), 0.005 ether / D, 0.009 ether / D, prover1);
        _transactExpectRevert(data1, prover1, "ZkBobPool: tree update fee is too low");

        bytes memory data2 = _encodePermitDeposit(int256(0.5 ether / D), 0.005 ether / D, 0.01 ether / D, prover1);
        _transact(data2, prover1);

        bytes memory data3 = _encodePermitDeposit(int256(0.5 ether / D), 0.005 ether / D, 0.011 ether / D, prover1);
        _transact(data3, prover1);
    }

    function testIndexInMessageEventIsConstructedCorrectly() public {
        uint256 index = pool.pool_index();
        deal(token, user1, 100 ether / D);

        bytes memory data1 = _encodePermitDeposit(int256(0.5 ether / D), 0.005 ether / D, 0.005 ether / D, prover1);
        vm.expectEmit(true, false, false, false);
        bytes memory message = new bytes(0);
        emit Message(index + 128, bytes32(0), message);
        _transact(data1, prover1);

        bytes memory data2 = _encodePermitDeposit(int256(0.5 ether / D), 0.005 ether / D, 0.005 ether / D, prover2);
        vm.expectEmit(true, false, false, false);
        emit Message(index + 2 * 128, bytes32(0), message);
        _transact(data2, prover2);

        (uint256[] memory indices, uint256 commitment, uint256[8] memory proof) = _prepareRandomDirectDeposits(0);
        vm.expectEmit(true, false, false, false);
        emit Message(index + 3 * 128, bytes32(0), message);
        _appendDirectDeposits(indices, commitment, proof, prover1);

        _proveTreeUpdate(prover1);
        _proveTreeUpdate(prover2);

        bytes memory data3 = _encodePermitDeposit(int256(0.5 ether / D), 0.005 ether / D, 0.005 ether / D, prover2);
        vm.expectEmit(true, false, false, false);
        emit Message(index + 4 * 128, bytes32(0), message);
        _transact(data3, prover2);

        _proveTreeUpdate(prover1);
        _proveTreeUpdate(prover2);

        (indices, commitment, proof) = _prepareRandomDirectDeposits(2);
        vm.expectEmit(true, false, false, false);
        emit Message(index + 5 * 128, bytes32(0), message);
        _appendDirectDeposits(indices, commitment, proof, prover2);

        _proveTreeUpdate(prover2);
    }

    function testDirectDepositsTreeUpdateFeeTooLow() public {
        _setUpDD();

        pool.setMinTreeUpdateFee(uint64(3));
        queue.setDirectDepositFee(uint64(1));

        vm.startPrank(user1);

        _directDeposit(10 ether / D, user2, zkAddress);
        _directDeposit(5 ether / D, user2, zkAddress);
        vm.stopPrank();

        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;

        uint256 outCommitment = _randFR();
        vm.prank(prover1);
        vm.expectRevert("ZkBobPool: tree update fee is too low");
        pool.appendDirectDeposits(indices, outCommitment, _randProof());
    }

    function testDirectDepositsTreeFeesAccrued() public {
        _setUpDD();

        uint64 minTreeUpdateFee = uint64(0.01 ether / (D * denominator));
        uint64 singleDirectDepositFee = uint64(0.1 ether / (D * denominator));

        pool.setMinTreeUpdateFee(minTreeUpdateFee);
        queue.setDirectDepositFee(singleDirectDepositFee);

        vm.startPrank(user1);
        _directDeposit(10 ether / D, user2, zkAddress);
        _directDeposit(5 ether / D, user2, zkAddress);
        vm.stopPrank();

        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;

        uint256 outCommitment = _randFR();
        vm.prank(prover1);
        pool.appendDirectDeposits(indices, outCommitment, _randProof());
        uint64 expectedFee = uint64(singleDirectDepositFee * 2 - minTreeUpdateFee);
        assertEq(expectedFee, pool.accumulatedFee(prover1));

        vm.prank(prover1);
        pool.withdrawFee(prover1, feeReceiver1);
        assertEq(IERC20(token).balanceOf(feeReceiver1), expectedFee * denominator);

        _proveTreeUpdate(prover1);
        assertEq(minTreeUpdateFee, pool.accumulatedFee(prover1));

        vm.prank(prover1);
        pool.withdrawFee(prover1, feeReceiver1);
        assertEq(IERC20(token).balanceOf(feeReceiver1), (expectedFee + minTreeUpdateFee) * denominator);
    }

    function _transact(bytes memory _data, address caller) internal {
        vm.prank(caller);
        (bool status,) = address(pool).call(_data);
        assertTrue(status);
    }

    function _transactExpectRevert(bytes memory _data, address caller, string memory expectedRevertReason) internal {
        vm.prank(caller);
        (bool status, bytes memory data) = address(pool).call(_data);
        assertFalse(status);
        assembly {
            data := add(data, 0x04)
        }
        bytes memory revertReason = abi.decode(data, (bytes));
        assertEq(revertReason, bytes(expectedRevertReason));
    }

    function _proveTreeUpdate(address caller) internal {
        (uint256 commitment,,,,) = pool.pendingCommitment();
        vm.prank(caller);
        pool.proveTreeUpdate(commitment, _randProof(), _randFR());
    }

    function _proveTreeUpdateExpectRevert(address caller, string memory expectedRevertReason) internal {
        (uint256 commitment,,,,) = pool.pendingCommitment();
        vm.expectRevert(bytes(expectedRevertReason));
        vm.prank(caller);
        pool.proveTreeUpdate(commitment, _randProof(), _randFR());
    }

    function _prepareRandomDirectDeposits(uint256 offset)
        internal
        returns (uint256[] memory indices, uint256 commitment, uint256[8] memory proof)
    {
        _setUpDD();

        vm.startPrank(user1);
        _directDeposit(1 ether / D, user2, zkAddress);
        _directDeposit(1 ether / D, user2, zkAddress);
        vm.stopPrank();

        indices = new uint256[](2);
        indices[0] = offset + 0;
        indices[1] = offset + 1;

        commitment = _randFR();
        proof = _randProof();
    }

    function _appendDirectDeposits(
        uint256[] memory indices,
        uint256 commitment,
        uint256[8] memory proof,
        address prover
    )
        internal
    {
        vm.prank(prover);
        pool.appendDirectDeposits(indices, commitment, proof);
    }
}

contract ZkBobPoolBOBPolygonDecentralizedTest is AbstractZkBobPoolDecentralizedTest, AbstractPolygonForkTest {
    constructor() {
        D = 1;
        token = address(0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B);
        weth = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
        tempToken = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        poolType = PoolType.BOB;
        autoApproveQueue = false;
        permitType = PermitType.BOBPermit;
        denominator = 1_000_000_000;
        precision = 1_000_000_000;
    }
}

contract ZkBobPoolETHMainnetDecentralizedTest is AbstractZkBobPoolDecentralizedTest, AbstractMainnetForkTest {
    constructor() {
        D = 1;
        token = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        tempToken = address(0);
        poolType = PoolType.ETH;
        autoApproveQueue = false;
        permitType = PermitType.Permit2;
        denominator = 1_000_000_000;
        precision = 1_000_000_000;
    }
}

contract ZkBobPoolDAIMainnetDecentralizedTest is AbstractZkBobPoolDecentralizedTest, AbstractMainnetForkTest {
    constructor() {
        D = 1;
        token = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        tempToken = address(0);
        poolType = PoolType.ERC20;
        autoApproveQueue = true;
        permitType = PermitType.Permit2;
        denominator = 1_000_000_000;
        precision = 1_000_000_000;
    }
}

contract ZkBobPoolUSDCPolygonDecentralizedTest is AbstractZkBobPoolDecentralizedTest, AbstractPolygonForkTest {
    constructor() {
        D = 10 ** 12;
        token = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        weth = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
        tempToken = address(0);
        poolType = PoolType.USDC;
        autoApproveQueue = true;
        permitType = PermitType.USDCPermit;
        denominator = 1;
        precision = 1_000_000;
    }
}
