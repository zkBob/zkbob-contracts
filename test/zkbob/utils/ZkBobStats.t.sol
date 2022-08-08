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
            pool.transact(100 * 100 ether);
            vm.warp(block.timestamp + 20 minutes);
        }
        assertEq(pool.weekMaxTvl(), 100);
        assertEq(pool.weekMaxCount(), 505);
        assertEq(pool.poolIndex(), 999 * 128);
        emit log_bytes32(pool.slot0());

        for (uint256 i = 0; i < 200; i++) {
            pool.transact((100 + i) * 100 ether);
            vm.warp(block.timestamp + 20 minutes);
        }

        assertGe(pool.weekMaxTvl(), 139);
        assertLe(pool.weekMaxTvl(), 140);
        assertEq(pool.weekMaxCount(), 505);
        assertEq(pool.poolIndex(), 1199 * 128);
        emit log_bytes32(pool.slot0());

        for (uint256 i = 0; i < 200; i++) {
            pool.transact(300 * 100 ether);
            vm.warp(block.timestamp + 10 minutes);
        }

        assertGe(pool.weekMaxTvl(), 198);
        assertLe(pool.weekMaxTvl(), 199);
        assertEq(pool.weekMaxCount(), 604);
        assertEq(pool.poolIndex(), 1399 * 128);
        emit log_bytes32(pool.slot0());

        for (uint256 i = 0; i < 1000; i++) {
            pool.transact(100 * 100 ether);
            vm.warp(block.timestamp + 30 minutes);
        }

        assertGe(pool.weekMaxTvl(), 198);
        assertLe(pool.weekMaxTvl(), 199);
        assertEq(pool.weekMaxCount(), 605);
        assertEq(pool.poolIndex(), 2399 * 128);
        emit log_bytes32(pool.slot0());

        // force tvl_cum overflow
        vm.store(address(pool), bytes32(0), bytes32(0x000000c70293e400000960fffd00000000000293e400000960fffd0000000000));
        for (uint256 i = 0; i <= 256 * 3; i++) {
            pool.transact(((1 << 32) - 1) * 100 ether);
            vm.warp(block.timestamp + 20 minutes);
        }

        assertEq(pool.weekMaxTvl(), (1 << 32) - 1);
        assertEq(pool.weekMaxCount(), 505);
        emit log_bytes32(pool.slot0());

        pool.transact(((1 << 32) - 1) * 100 ether);
        assertEq(pool.weekMaxTvl(), (1 << 32) - 1);
        assertEq(pool.weekMaxCount(), 505);
        emit log_bytes32(pool.slot0());
    }
}
