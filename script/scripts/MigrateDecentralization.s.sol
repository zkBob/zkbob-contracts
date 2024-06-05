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
address constant operatorManagerOwner = 0x14fc6a1a996A2EB889cF86e5c8cD17323bC85290;

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
address constant zkBobProxyFeeReceiver1 = 0x7D2D146a7AD3F0Dc398AA718a9bFCa2Bc873a5FD;
address constant zkBobProxy2 = 0xFec49782FE8e11De9Fb3Ba645a76FE914FFfe3cb;
address constant zkBobProxyFeeReceiver2 = 0xFec49782FE8e11De9Fb3Ba645a76FE914FFfe3cb;
address constant zkBobProver1 = 0x33a0b018340d6424870cfC686a4d02e1df792254;
address constant zkBobProverFeeReceiver1 = 0x33a0b018340d6424870cfC686a4d02e1df792254;
address constant zkBobProver2 = 0x63A88E69fa7adEf036fc6ED94394CC9295de2f99;
address constant zkBobProverFeeReceiver2 = 0x63A88E69fa7adEf036fc6ED94394CC9295de2f99;

// Only for checks:
address constant relayer = 0xb9CD01c0b417b4e9095f620aE2f849A84a9B1690;

contract UpgradeTest is Test {
    struct PoolSnapshot {
        address owner;
        uint256 poolIndex;
        uint256 oneNullifier;
        uint256 lastRoot;
        bytes32 all_messages_hash;
        uint256 relayerFee;
        address tokenSeller;
        address accounting;
    }

    function makeSnapshot(ZkBobPoolUSDC _pool) internal view returns (PoolSnapshot memory) {
        return PoolSnapshot({
            owner: _pool.owner(),
            poolIndex: _pool.pool_index(),
            oneNullifier: _pool.nullifiers(0x39a833a5c374a0a3328f65ae9a9bf883945694cca613a8415c3a555bda388cd),
            lastRoot: _pool.roots(_pool.pool_index()),
            all_messages_hash: _pool.all_messages_hash(),
            relayerFee: _pool.accumulatedFee(relayer),
            tokenSeller: address(_pool.tokenSeller()),
            accounting: address(_pool.accounting())
        });
    }

    function postCheck(ZkBobPoolUSDC _pool, PoolSnapshot memory _snapshot) internal {
        assertEq(_snapshot.owner, _pool.owner());
        assertEq(_snapshot.poolIndex, uint256(_pool.pool_index()));
        assertEq(
            _snapshot.oneNullifier, _pool.nullifiers(0x39a833a5c374a0a3328f65ae9a9bf883945694cca613a8415c3a555bda388cd)
        );
        assertEq(_snapshot.lastRoot, _pool.roots(_pool.pool_index()));
        assertEq(_snapshot.all_messages_hash, _pool.all_messages_hash());
        assertEq(_snapshot.relayerFee, _pool.accumulatedFee(relayer));
        assertEq(_snapshot.tokenSeller, address(_pool.tokenSeller()));
        assertEq(_snapshot.accounting, address(_pool.accounting()));
        assertEq(gracePeriod, _pool.gracePeriod());
        assertEq(minTreeUpdateFee, _pool.minTreeUpdateFee());

        vm.expectRevert("ZkBobPool: queue is empty");
        _pool.pendingCommitment();
    }
}

/**
 * @dev Don't forget to set ZkBobPool.TOKEN_NUMERATOR to 1000 for USDC pools.
 */
contract MigrateDecentralization is Script, UpgradeTest {
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

        migrateDecentralization(address(pool), address(snapshot.tokenSeller));

        vm.stopBroadcast();

        postCheck(ZkBobPoolUSDC(address(pool)), snapshot);
    }

    function migrateDecentralization(address _pool, address _tokenSeller) internal {
        // 3. Set grace period
        ZkBobPool(_pool).setGracePeriod(gracePeriod);
        // 4. Set min tree update fee
        ZkBobPool(_pool).setMinTreeUpdateFee(minTreeUpdateFee);
        // 5. Set token seller
        ZkBobPoolUSDC(_pool).setTokenSeller(_tokenSeller);

        // 6. Deploy AllowListOperatorManager
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

        // 7. Set operator manager
        ZkBobPool(_pool).setOperatorManager(operatorManager);

        // 8. Transfer operator manager ownership to the owner
        operatorManager.transferOwnership(operatorManagerOwner);
    }
}
