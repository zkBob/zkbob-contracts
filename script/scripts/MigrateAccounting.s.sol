// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {ZkBobPool, ZkBobPoolUSDC} from "../../src/zkbob/ZkBobPoolUSDC.sol";
import {IZkBobAccounting, IKycProvidersManager, ZkBobAccounting} from "../../src/zkbob/utils/ZkBobAccounting.sol";
import {EIP1967Proxy} from "../../src/proxy/EIP1967Proxy.sol";

/**
 * @dev OP-USDC pool proxy address.
 */
address constant zkBobPool = 0x1CA8C2B9B20E18e86d5b9a72370fC6c91814c97C;

/**
 * @dev This address will become an owner of the the new ZkBobAccounting contract.
 */
address constant accountingOwner = 0x14fc6a1a996A2EB889cF86e5c8cD17323bC85290;

// Used to check that the relayer fee is correctly migrated
address constant relayer = 0xb9CD01c0b417b4e9095f620aE2f849A84a9B1690;

contract UpgradeTest is Test {
    struct PoolSnapshot {
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

/**
 * @dev Don't forget to set ZkBobPool.TOKEN_NUMERATOR to 1000 for USDC pools.
 */
contract MigrateAccounting is Script, UpgradeTest {
    function run() external {
        ZkBobPoolUSDC pool = ZkBobPoolUSDC(address(zkBobPool));
        PoolSnapshot memory snapshot = makeSnapshot(pool);

        vm.startBroadcast();

        // 1. Deploy new ZkBobPoolUSDC implementation
        ZkBobPoolUSDC newImpl = new ZkBobPoolUSDC(
            pool.pool_id(),
            pool.token(),
            pool.transfer_verifier(),
            pool.tree_verifier(),
            pool.batch_deposit_verifier(),
            address(pool.direct_deposit_queue())
        );

        // 2. Upgrade proxy to new implementation
        EIP1967Proxy(payable(address(pool))).upgradeTo(address(newImpl));

        migrateAccounting(address(pool), address(snapshot.kycManager));

        vm.stopBroadcast();

        postCheck(ZkBobPoolUSDC(address(pool)), snapshot);
    }

    // TODO: Check limits
    function migrateAccounting(address _pool, address _kycManager) internal {
        // 3. Deploy new ZkBobAccounting implementation
        ZkBobAccounting accounting = new ZkBobAccounting(address(_pool), 1_000_000_000);

        bytes memory dump = ZkBobPool(_pool).extsload(bytes32(uint256(1)), 2);
        uint32 txCount = uint32(_load(dump, 0, 4));
        uint88 cumTvl = uint88(_load(dump, 4, 11));
        uint32 maxWeeklyTxCount = uint32(_load(dump, 21, 4));
        uint56 maxWeeklyAvgTvl = uint56(_load(dump, 25, 7));
        uint72 tvl = uint72(_load(dump, 55, 9));

        // 4. Initialize pool index
        ZkBobPool(_pool).initializePoolIndex(txCount * 128);
        // 5. Set accounting
        ZkBobPool(_pool).setAccounting(IZkBobAccounting(accounting));

        // 6. Initialize accounting
        ZkBobAccounting(accounting).initialize(txCount, tvl, cumTvl, maxWeeklyTxCount, maxWeeklyAvgTvl);
        // 7. Set kyc providers manager
        ZkBobAccounting(accounting).setKycProvidersManager(IKycProvidersManager(_kycManager));
        // 8. Set limits for tier 0
        ZkBobAccounting(accounting).setLimits(
            0, 2_000_000 gwei, 300_000 gwei, 300_000 gwei, 10_000 gwei, 10_000 gwei, 10_000 gwei, 1_000 gwei
        );
        // 9. Set limits for tier 1
        ZkBobAccounting(accounting).setLimits(
            1, 2_000_000 gwei, 300_000 gwei, 300_000 gwei, 100_000 gwei, 100_000 gwei, 10_000 gwei, 1_000 gwei
        );
        // 10. Set limits for tier 254
        ZkBobAccounting(accounting).setLimits(
            254, 2_000_000 gwei, 300_000 gwei, 300_000 gwei, 20_000 gwei, 20_000 gwei, 10_000 gwei, 1_000 gwei
        );

        // 11. Transfer accounting accounting ownership to the owner
        accounting.transferOwnership(accountingOwner);
    }

    function _load(bytes memory _dump, uint256 _from, uint256 _len) internal pure returns (uint256 res) {
        assembly {
            res := shr(sub(256, shl(3, _len)), mload(add(_dump, add(32, _from))))
        }
    }
}
