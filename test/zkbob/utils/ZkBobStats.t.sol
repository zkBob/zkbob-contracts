// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../../mocks/ZkBobStatsMock.sol";

contract ZkBobPoolStatsTest is Test {
    ZkBobStatsMock pool;

    function setUp() public {
        pool = new ZkBobStatsMock();

        vm.warp(1000 weeks);
    }

    function testBasicStats() public {
        emit log_bytes32(pool.slot0());

        // baseline
        for (uint256 i = 0; i < 1000; i++) {
            pool.transact(100 ether);
            vm.warp(block.timestamp + 20 minutes);
        }
        assertEq(pool.weekMaxTvl(), 100);
        assertEq(pool.weekMaxCount(), 504);
        assertEq(pool.poolIndex(), 999 * 128);
        emit log_bytes32(pool.slot0());

        for (uint256 i = 0; i < 200; i++) {
            // not hour module 0
            pool.transact((100 + i) * 1 ether);
            vm.warp(block.timestamp + 20 minutes);
        }

        assertGe(pool.weekMaxTvl(), 137);
        assertLe(pool.weekMaxTvl(), 148);
        assertEq(pool.weekMaxCount(), 504);
        assertEq(pool.poolIndex(), 1199 * 128);
        emit log_bytes32(pool.slot0());

        for (uint256 i = 0; i < 200; i++) {
            pool.transact(300 ether);
            vm.warp(block.timestamp + 10 minutes);
        }

        assertGe(pool.weekMaxTvl(), 198);
        assertLe(pool.weekMaxTvl(), 199);
        assertEq(pool.weekMaxCount(), 603);
        assertEq(pool.poolIndex(), 1399 * 128);
        emit log_bytes32(pool.slot0());

        for (uint256 i = 0; i < 1000; i++) {
            pool.transact(100 ether);
            vm.warp(block.timestamp + 30 minutes);
        }

        assertGe(pool.weekMaxTvl(), 213);
        assertLe(pool.weekMaxTvl(), 214);
        assertEq(pool.weekMaxCount(), 604);
        assertEq(pool.poolIndex(), 2399 * 128);
        emit log_bytes32(pool.slot0());
    }

    function testSparseIntervals() public {
        emit log_bytes32(pool.slot0());

        // baseline
        for (uint256 i = 0; i < 1000; i++) {
            pool.transact(100 ether);
            vm.warp(block.timestamp + 20 minutes);
        }
        for (uint256 i = 1; i <= 10; i++) {
            for (uint256 j = 0; j < 10; j++) {
                pool.transact(200 ether);
            }
            vm.warp(block.timestamp + i * 1 hours);
        }
        for (uint256 i = 0; i < 1000; i++) {
            pool.transact(100 ether);
            vm.warp(block.timestamp + 30 minutes);
        }
        assertEq(pool.weekMaxTvl(), 130);
        assertEq(pool.weekMaxCount(), 524);
        assertEq(pool.poolIndex(), 2099 * 128);
        emit log_bytes32(pool.slot0());
    }
}
