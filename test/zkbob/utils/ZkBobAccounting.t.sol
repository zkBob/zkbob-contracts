// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../../shared/Env.t.sol";
import "../../mocks/ZkBobAccountingMock.sol";

contract ZkBobAccountingTest is Test {
    ZkBobAccountingMock pool;

    function setUp() public {
        pool = new ZkBobAccountingMock();

        pool.setLimits(1000 ether, 1000 ether, 1000 ether, 1000 ether);

        vm.warp(1000 weeks);
    }

    function testBasicStats() public {
        emit log_bytes32(pool.slot0());

        // baseline
        for (uint256 i = 0; i < 1000; i++) {
            pool.transact(i == 0 ? int256(100 ether) : int256(0));
            vm.warp(block.timestamp + 20 minutes);
        }
        assertEq(pool.weekMaxTvl(), 100);
        assertEq(pool.weekMaxCount(), 504);
        assertEq(pool.poolIndex(), 999 * 128);
        emit log_bytes32(pool.slot0());

        for (uint256 i = 0; i < 200; i++) {
            pool.transact(1 ether);
            vm.warp(block.timestamp + 20 minutes);
        }

        assertEq(pool.weekMaxTvl(), 138);
        assertEq(pool.weekMaxCount(), 504);
        assertEq(pool.poolIndex(), 1199 * 128);
        emit log_bytes32(pool.slot0());

        for (uint256 i = 0; i < 200; i++) {
            pool.transact(0);
            vm.warp(block.timestamp + 10 minutes);
        }

        assertEq(pool.weekMaxTvl(), 198);
        assertEq(pool.weekMaxCount(), 603);
        assertEq(pool.poolIndex(), 1399 * 128);
        emit log_bytes32(pool.slot0());

        for (uint256 i = 0; i < 1000; i++) {
            pool.transact(i == 0 ? int256(-200 ether) : int256(0));
            vm.warp(block.timestamp + 30 minutes);
        }

        assertEq(pool.weekMaxTvl(), 213);
        assertEq(pool.weekMaxCount(), 604);
        assertEq(pool.poolIndex(), 2399 * 128);
        emit log_bytes32(pool.slot0());
    }

    function testSparseIntervals() public {
        emit log_bytes32(pool.slot0());

        // baseline
        for (uint256 i = 0; i < 1000; i++) {
            pool.transact(i == 0 ? int256(100 ether) : int256(0));
            vm.warp(block.timestamp + 20 minutes);
        }
        for (uint256 i = 1; i <= 10; i++) {
            for (uint256 j = 0; j < 10; j++) {
                pool.transact(i == 1 && j == 0 ? int256(100 ether) : int256(0));
            }
            vm.warp(block.timestamp + i * 1 hours);
        }
        for (uint256 i = 0; i < 1000; i++) {
            pool.transact(i == 0 ? int256(-100 ether) : int256(0));
            vm.warp(block.timestamp + 30 minutes);
        }
        assertEq(pool.weekMaxTvl(), 130);
        assertEq(pool.weekMaxCount(), 524);
        assertEq(pool.poolIndex(), 2099 * 128);
        emit log_bytes32(pool.slot0());
    }

    function testDepositCap() public {
        pool.setLimits(1000 ether, 500 ether, 300 ether, 100 ether);

        vm.expectRevert("ZkBobAccounting: single deposit cap exceeded");
        pool.transact(200 ether);
        pool.transact(100 ether);
        pool.transact(50 ether);
    }

    function testDailyUserDepositCap() public {
        pool.setLimits(1000 ether, 500 ether, 200 ether, 100 ether);

        pool.transact(100 ether);
        pool.transact(100 ether);
        vm.expectRevert("ZkBobAccounting: daily user deposit cap exceeded");
        pool.transact(100 ether);
    }

    function testDailyDepositCap() public {
        pool.setLimits(1000 ether, 500 ether, 200 ether, 100 ether);

        pool.transact(100 ether);
        pool.transact(100 ether);

        vm.startPrank(user1);
        pool.transact(100 ether);
        pool.transact(100 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        pool.transact(100 ether);
        vm.expectRevert("ZkBobAccounting: daily deposit cap exceeded");
        pool.transact(100 ether);
        vm.stopPrank();
    }

    function testTvlCap() public {
        pool.setLimits(1000 ether, 500 ether, 200 ether, 100 ether);

        for (uint256 i = 0; i < 10; i++) {
            pool.transact(100 ether);
            vm.warp(block.timestamp + 1 days);
        }

        vm.expectRevert("ZkBobAccounting: tvl cap exceeded");
        pool.transact(100 ether);
    }

    function testDailyUserDepositCapReset() public {
        pool.setLimits(10000 ether, 500 ether, 200 ether, 100 ether);

        for (uint256 i = 0; i < 5; i++) {
            pool.transact(100 ether);
            pool.transact(100 ether);
            vm.expectRevert("ZkBobAccounting: daily user deposit cap exceeded");
            pool.transact(100 ether);

            vm.warp(block.timestamp + 1 days);
        }
    }

    function testDailyDepositCapReset() public {
        pool.setLimits(10000 ether, 500 ether, 300 ether, 150 ether);

        for (uint256 i = 0; i < 5; i++) {
            pool.transact(150 ether);
            vm.prank(user1);
            pool.transact(150 ether);
            vm.prank(user2);
            pool.transact(150 ether);

            vm.expectRevert("ZkBobAccounting: daily deposit cap exceeded");
            pool.transact(150 ether);
            vm.prank(user1);
            vm.expectRevert("ZkBobAccounting: daily deposit cap exceeded");
            pool.transact(150 ether);
            vm.prank(user2);
            vm.expectRevert("ZkBobAccounting: daily deposit cap exceeded");
            pool.transact(150 ether);

            vm.warp(block.timestamp + 1 days);
        }
    }

    function testGetLimitsFor() public {
        pool.setLimits(10000 ether, 500 ether, 300 ether, 150 ether);

        uint256[7] memory limits1;
        uint256[7] memory limits2;

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1[0], 10000 gwei);
        assertEq(limits1[1], 0 gwei);
        assertEq(limits1[2], 500 gwei);
        assertEq(limits1[3], 0 gwei);
        assertEq(limits1[4], 300 gwei);
        assertEq(limits1[5], 0 gwei);
        assertEq(limits1[6], 150 gwei);

        vm.startPrank(user1);
        pool.transact(50 ether);
        pool.transact(70 ether);
        vm.stopPrank();

        vm.prank(user2);
        pool.transact(100 ether);
        vm.stopPrank();

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1[0], 10000 gwei);
        assertEq(limits1[1], 220 gwei);
        assertEq(limits1[2], 500 gwei);
        assertEq(limits1[3], 220 gwei);
        assertEq(limits1[4], 300 gwei);
        assertEq(limits1[5], 120 gwei);
        assertEq(limits1[6], 150 gwei);

        limits2 = pool.getLimitsFor(user2);
        assertEq(limits2[0], 10000 gwei);
        assertEq(limits2[1], 220 gwei);
        assertEq(limits2[2], 500 gwei);
        assertEq(limits2[3], 220 gwei);
        assertEq(limits2[4], 300 gwei);
        assertEq(limits2[5], 100 gwei);
        assertEq(limits2[6], 150 gwei);

        vm.warp(block.timestamp + 1 days);

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1[0], 10000 gwei);
        assertEq(limits1[1], 220 gwei);
        assertEq(limits1[2], 500 gwei);
        assertEq(limits1[3], 0 gwei);
        assertEq(limits1[4], 300 gwei);
        assertEq(limits1[5], 0 gwei);
        assertEq(limits1[6], 150 gwei);

        limits2 = pool.getLimitsFor(user2);
        assertEq(limits2[0], 10000 gwei);
        assertEq(limits2[1], 220 gwei);
        assertEq(limits2[2], 500 gwei);
        assertEq(limits2[3], 0 gwei);
        assertEq(limits2[4], 300 gwei);
        assertEq(limits2[5], 0 gwei);
        assertEq(limits2[6], 150 gwei);
    }
}
