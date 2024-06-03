// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "../../src/zkbob/ZkBobPoolUSDC.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/utils/ZkBobAccounting.sol";
import "../../src/zkbob/manager/AllowListOperatorManager.sol";

/**
 * @dev OP-USDC pool proxy address.
 */
address constant zkBobPool = 0x1CA8C2B9B20E18e86d5b9a72370fC6c91814c97C;

/**
 * @dev This address will become an owner of the new ZkBobAccounting and AllowListOperatorManager contracts.
 */
address constant owner = 0x14fc6a1a996A2EB889cF86e5c8cD17323bC85290;

/**
 * @dev This value should be sufficient for dedicated prover to update the tree
 * but not too big to support liveness.
 */
uint64 constant gracePeriod = 3 minutes;

/**
 * @dev This value should cover the cost of the tree update.
 */
uint64 constant minTreeUpdateFee = 0.1 gwei;

/**
 * @dev AllowListOperatorManager related parameters.
 */
bool constant allowListEnabled = true;
// TODO: Update this addresses before deployment
address constant zkBobProxy1 = 0x7D2D146a7AD3F0Dc398AA718a9bFCa2Bc873a5FD;
address constant zkBobProxy2 = 0xFec49782FE8e11De9Fb3Ba645a76FE914FFfe3cb;
address constant zkBobProxyFeeReceiver1 = 0x7D2D146a7AD3F0Dc398AA718a9bFCa2Bc873a5FD;
address constant zkBobProxyFeeReceiver2 = 0xFec49782FE8e11De9Fb3Ba645a76FE914FFfe3cb;
address constant zkBobProver1 = 0x33a0b018340d6424870cfC686a4d02e1df792254;
address constant zkBobProver2 = 0x63A88E69fa7adEf036fc6ED94394CC9295de2f99;
address constant zkBobProverFeeReceiver1 = 0x33a0b018340d6424870cfC686a4d02e1df792254;
address constant zkBobProverFeeReceiver2 = 0x63A88E69fa7adEf036fc6ED94394CC9295de2f99;

// Only for checks:
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
        assertEq(gracePeriod, _pool.gracePeriod());
        assertEq(minTreeUpdateFee, _pool.minTreeUpdateFee());
        assertEq(_snapshot.tokenSeller, address(_pool.tokenSeller()));
        assertEq(_snapshot.kycManager, address(ZkBobAccounting(address(_pool.accounting())).kycProvidersManager()));

        checkSlot0(uint256(_snapshot.slot0), ZkBobAccounting(address(_pool.accounting())));
        checkSlot1(uint256(_snapshot.slot1), ZkBobAccounting(address(_pool.accounting())));

        vm.expectRevert("ZkBobPool: queue is empty");
        _pool.pendingCommitment();
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
contract DecentralizationUpgrade is Script, UpgradeTest {
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
        migrateDecentralization(address(pool), address(snapshot.tokenSeller));

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
        accounting.transferOwnership(owner);
    }

    function migrateDecentralization(address _pool, address _tokenSeller) internal {
        // 12. Set grace period
        ZkBobPool(_pool).setGracePeriod(gracePeriod);
        // 13. Set min tree update fee
        ZkBobPool(_pool).setMinTreeUpdateFee(minTreeUpdateFee);
        // 14. Set token seller
        ZkBobPoolUSDC(_pool).setTokenSeller(_tokenSeller);

        // 15. Deploy AllowListOperatorManager
        address[] memory operators = new address[](4);
        operators[0] = zkBobProxy1;
        operators[1] = zkBobProver1;
        operators[2] = zkBobProxy2;
        operators[3] = zkBobProver2;

        address[] memory feeReceivers = new address[](4);
        feeReceivers[0] = zkBobProxyFeeReceiver1;
        feeReceivers[1] = zkBobProverFeeReceiver1;
        feeReceivers[2] = zkBobProxyFeeReceiver2;
        feeReceivers[3] = zkBobProverFeeReceiver2;

        AllowListOperatorManager operatorManager =
            new AllowListOperatorManager(operators, feeReceivers, allowListEnabled);

        // 16. Set operator manager
        ZkBobPool(_pool).setOperatorManager(operatorManager);

        // 17. Transfer operator manager ownership to the owner
        operatorManager.transferOwnership(owner);
    }

    function _load(bytes memory _dump, uint256 _from, uint256 _len) internal pure returns (uint256 res) {
        assembly {
            res := shr(sub(256, shl(3, _len)), mload(add(_dump, add(32, _from))))
        }
    }
}
