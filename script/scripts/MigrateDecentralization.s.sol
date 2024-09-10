// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "../../src/zkbob/ZkBobPoolUSDC.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/utils/ZkBobAccounting.sol";
import "../../src/zkbob/manager/AllowListOperatorManager.sol";

// TODO: update this parameters before running the script
address constant newZkBobPoolImpl = 0x0114Bf30d9f5A7f503D3DFC65534F2B5AC302c85;
address constant newOperatorManager = 0xFd5a6a67D768d5BF1A8c7724387CA8786Bd4DD91;

/**
 * @dev OP-USDC pool proxy address.
 */
address constant zkBobPool = 0x1CA8C2B9B20E18e86d5b9a72370fC6c91814c97C;

/**
 * @dev This value should be sufficient for dedicated prover to update the tree
 * but not too big to support liveness.
 */
uint64 constant gracePeriod = 3 minutes;

/**
 * @dev This value should cover the cost of the tree update.
 */
uint64 constant minTreeUpdateFee = 0.1 gwei;

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

        // 1. Upgrade proxy to new implementation
        EIP1967Proxy(payable(address(pool))).upgradeTo(address(newZkBobPoolImpl));

        // 2. Set grace period
        ZkBobPool(pool).setGracePeriod(gracePeriod);
        // 3. Set min tree update fee
        ZkBobPool(pool).setMinTreeUpdateFee(minTreeUpdateFee);
        // 4. Set token seller
        ZkBobPoolUSDC(pool).setTokenSeller(snapshot.tokenSeller);
        // 5. Set operator manager
        ZkBobPool(pool).setOperatorManager(AllowListOperatorManager(newOperatorManager));

        vm.stopBroadcast();

        postCheck(ZkBobPoolUSDC(address(pool)), snapshot);
    }
}
