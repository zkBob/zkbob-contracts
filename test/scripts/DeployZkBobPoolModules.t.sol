// SPDX-License-Identifier: CC0-1.0

import {Test, console} from "forge-std/Test.sol";
import {AbstractOptimismForkTest} from "../shared/ForkTests.t.sol";
import {ZkBobPoolUSDC} from "../../src/zkbob/ZkBobPoolUSDC.sol";
import {DeployZkBobPoolModules} from "../../script/scripts/DeployZkBobPoolModules.s.sol";
import {EIP1967Proxy} from "../../src/proxy/EIP1967Proxy.sol";
import {ZkBobAccounting} from "../../src/zkbob/utils/ZkBobAccounting.sol";

contract DeployZkBobPoolModulesTest is AbstractOptimismForkTest {
    struct PoolStateCheck {
        address owner;
        bytes32 slot0;
        bytes32 slot1;
        address operatorManager;
        uint256 poolIndex;
        uint256 oneNullifier;
        uint256 lastRoot;
        bytes32 all_messages_hash;
        uint256 relayerFee;
        address tokenSeller;
    }

    function testOptimismUSDCPoolUpgrade() public {
        vm.createSelectFork(forkRpcUrl, 116204904);
        ZkBobPoolUSDC pool = ZkBobPoolUSDC(0x1CA8C2B9B20E18e86d5b9a72370fC6c91814c97C);
        address relayer = 0xb9CD01c0b417b4e9095f620aE2f849A84a9B1690;

        DeployZkBobPoolModules upgrade = new DeployZkBobPoolModules();

        // DeployZkBobPoolModules assumes that proxyAdmin is the owner of the pool
        address proxyAdmin = EIP1967Proxy(payable(address(pool))).admin();
        address owner = pool.owner();
        vm.prank(owner);
        pool.transferOwnership(address(proxyAdmin));

        // stack to deep
        PoolStateCheck memory poolState = PoolStateCheck({
            owner: pool.owner(),
            slot0: vm.load(address(pool), bytes32(uint256(1))),
            slot1: vm.load(address(pool), bytes32(uint256(2))),
            operatorManager: address(pool.operatorManager()),
            poolIndex: pool.pool_index(),
            oneNullifier: pool.nullifiers(0x39a833a5c374a0a3328f65ae9a9bf883945694cca613a8415c3a555bda388cd),
            lastRoot: pool.roots(pool.pool_index()),
            all_messages_hash: pool.all_messages_hash(),
            relayerFee: pool.accumulatedFee(relayer),
            tokenSeller: address(pool.tokenSeller())
        });

        startHoax(proxyAdmin);
        upgrade.runWithPoolAddress(address(pool), false);
        vm.stopPrank();

        assertEq(poolState.owner, pool.owner());
        assertEq(address(pool.redeemer()), address(0)); // redeemer is not set by script
        assertNotEq(address(pool.accounting()), address(0));
        assertEq(poolState.poolIndex, uint256(pool.pool_index()));
        assertEq(poolState.operatorManager, address(pool.operatorManager()));
        assertEq(
            poolState.oneNullifier, pool.nullifiers(0x39a833a5c374a0a3328f65ae9a9bf883945694cca613a8415c3a555bda388cd)
        );
        assertEq(poolState.lastRoot, pool.roots(pool.pool_index()));
        assertEq(poolState.all_messages_hash, pool.all_messages_hash());
        assertEq(poolState.relayerFee, pool.accumulatedFee(relayer));
        assertEq(10 minutes, pool.gracePeriod());
        assertEq(0.1 gwei, pool.minTreeUpdateFee());
        assertEq(poolState.tokenSeller, address(pool.tokenSeller()));

        checkSlot0(uint256(poolState.slot0), ZkBobAccounting(address(pool.accounting())));
        checkSlot1(uint256(poolState.slot1), ZkBobAccounting(address(pool.accounting())));

        vm.expectRevert("ZkBobPool: queue is empty");
        pool.pendingCommitment();
    }

    function checkSlot0(uint256 slot0, ZkBobAccounting accounting) internal {
        (
            uint56 maxWeeklyAvgTvl,
            uint32 maxWeeklyTxCount,
            uint24 tailSlot,
            uint24 headSlot,
            uint88 cumTvl,
            uint32 txCount
        ) = accounting.slot0();
        uint24 curSlot = uint24(block.timestamp / 1 hours);

        assertEq(uint56(slot0), maxWeeklyAvgTvl);
        assertEq(uint32(slot0 >> 56), maxWeeklyTxCount);
        assertEq(curSlot, tailSlot);
        assertEq(curSlot, headSlot);
        assertEq(uint88(slot0 >> (56 + 32 + 24 + 24)), cumTvl);
        assertEq(uint32(slot0 >> (56 + 32 + 24 + 24 + 88)), txCount);
    }

    function checkSlot1(uint256 slot1, ZkBobAccounting accounting) internal {
        (uint72 tvl) = accounting.slot1();
        assertEq(uint72(slot1), tvl);
    }
}
