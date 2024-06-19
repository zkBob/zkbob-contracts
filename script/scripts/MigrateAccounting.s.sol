// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {ZkBobPool, ZkBobPoolUSDC} from "../../src/zkbob/ZkBobPoolUSDC.sol";
import {IZkBobAccounting, IKycProvidersManager, ZkBobAccounting} from "../../src/zkbob/utils/ZkBobAccounting.sol";
import {EIP1967Proxy} from "../../src/proxy/EIP1967Proxy.sol";
import {AccountingMigrator} from "./helpers/AccountingMigrator.sol";

// WARN: Update this values before running the script
address constant newZkBobPoolImpl = 0xD217AEf4aB37F7CeE7462d25cbD91f46c1E688a9;
address constant zkBobAccounting = 0xFd5a6a67D768d5BF1A8c7724387CA8786Bd4DD91;
address constant accountingMigrator = 0x0114Bf30d9f5A7f503D3DFC65534F2B5AC302c85;
address constant accountingOwner = 0x14fc6a1a996A2EB889cF86e5c8cD17323bC85290;

/**
 * @dev OP-USDC pool proxy address.
 */
address constant zkBobPool = 0x1CA8C2B9B20E18e86d5b9a72370fC6c91814c97C;

// Used to check that the relayer fee is correctly migrated
address constant relayer = 0xb9CD01c0b417b4e9095f620aE2f849A84a9B1690;

contract UpgradeTest is Test {
    struct PoolSnapshot {
        address proxyAdmin;
        address owner;
        bytes32 slot0;
        bytes32 slot1;
        uint256 poolIndex;
        uint256 oneNullifier;
        uint256 lastRoot;
        bytes32 all_messages_hash;
        uint256 relayerFee;
        address tokenSeller;
        address kycManager;
    }

    function makeSnapshot(ZkBobPoolUSDC _pool) internal view returns (PoolSnapshot memory) {
        return PoolSnapshot({
            proxyAdmin: EIP1967Proxy(payable(address(_pool))).admin(),
            owner: _pool.owner(),
            slot0: vm.load(address(_pool), bytes32(uint256(1))),
            slot1: vm.load(address(_pool), bytes32(uint256(2))),
            poolIndex: _pool.pool_index(),
            oneNullifier: _pool.nullifiers(0x39a833a5c374a0a3328f65ae9a9bf883945694cca613a8415c3a555bda388cd),
            lastRoot: _pool.roots(_pool.pool_index()),
            all_messages_hash: _pool.all_messages_hash(),
            relayerFee: _pool.accumulatedFee(relayer),
            tokenSeller: address(_pool.tokenSeller()),
            kycManager: address(ZkBobAccounting(address(_pool)).kycProvidersManager())
        });
    }

    function postCheck(ZkBobPoolUSDC _pool, PoolSnapshot memory _snapshot) internal {
        assertEq(_snapshot.proxyAdmin, EIP1967Proxy(payable(address(_pool))).admin());
        assertEq(_snapshot.owner, _pool.owner());
        assertEq(address(_pool.redeemer()), address(0)); // redeemer is not set by script
        assertNotEq(address(_pool.accounting()), address(0));
        assertEq(_snapshot.poolIndex, uint256(_pool.pool_index()));
        assertEq(
            _snapshot.oneNullifier, _pool.nullifiers(0x39a833a5c374a0a3328f65ae9a9bf883945694cca613a8415c3a555bda388cd)
        );
        assertEq(_snapshot.lastRoot, _pool.roots(_pool.pool_index()));
        assertEq(_snapshot.all_messages_hash, _pool.all_messages_hash());
        assertEq(_snapshot.relayerFee, _pool.accumulatedFee(relayer));
        assertEq(_snapshot.tokenSeller, address(_pool.tokenSeller()));
        assertEq(_snapshot.kycManager, address(ZkBobAccounting(address(_pool.accounting())).kycProvidersManager()));
        assertEq(accountingOwner, ZkBobAccounting(address(_pool.accounting())).owner());

        checkSlot0(uint256(_snapshot.slot0), ZkBobAccounting(address(_pool.accounting())));
        checkSlot1(uint256(_snapshot.slot1), ZkBobAccounting(address(_pool.accounting())));
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

contract MigrateAccounting is Script, UpgradeTest {
    function run() external {
        ZkBobPoolUSDC pool = ZkBobPoolUSDC(address(zkBobPool));
        AccountingMigrator migrator = AccountingMigrator(accountingMigrator);
        PoolSnapshot memory snapshot = makeSnapshot(pool);

        vm.startBroadcast();

        EIP1967Proxy(payable(address(pool))).upgradeTo(address(newZkBobPoolImpl));

        EIP1967Proxy(payable(address(pool))).setAdmin(accountingMigrator);

        ZkBobAccounting(zkBobAccounting).transferOwnership(accountingMigrator);

        migrator.migrate(address(pool), zkBobAccounting, snapshot.kycManager, accountingOwner, snapshot.proxyAdmin);

        vm.stopBroadcast();

        postCheck(ZkBobPoolUSDC(address(pool)), snapshot);
    }
}
