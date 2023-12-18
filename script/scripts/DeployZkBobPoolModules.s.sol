// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "./Env.s.sol";
import "../../src/zkbob/ZkBobPool.sol";
import "../../src/zkbob/utils/ZkBobAccounting.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPoolUSDC.sol";

contract DummyDelegateCall {
    function delegate(address to, bytes calldata data) external {
        (bool status,) = address(to).delegatecall(data);
        require(status);
    }
}

contract Migrator {
    function migrate(address _target, address _newImpl, address _accounting) external {
        address kycManager = address(ZkBobAccounting(_target).kycProvidersManager());

        EIP1967Proxy(payable(_target)).upgradeTo(_newImpl);

        bytes memory dump = ZkBobPool(_target).extsload(bytes32(uint256(1)), 2);
        uint32 txCount = uint32(_load(dump, 0, 4));
        uint88 cumTvl = uint88(_load(dump, 4, 11));
        uint32 maxWeeklyTxCount = uint32(_load(dump, 21, 4));
        uint56 maxWeeklyAvgTvl = uint56(_load(dump, 25, 7));
        uint72 tvl = uint72(_load(dump, 55, 9));

        ZkBobPool(_target).initializePoolIndex(txCount * 128);
        ZkBobPool(_target).setAccounting(IZkBobAccounting(_accounting));
        ZkBobAccounting(_accounting).initialize(txCount + 1, tvl, cumTvl, maxWeeklyTxCount, maxWeeklyAvgTvl);
        ZkBobAccounting(_accounting).setKycProvidersManager(IKycProvidersManager(kycManager));
        ZkBobAccounting(_accounting).setLimits(
            0, 2_000_000 gwei, 300_000 gwei, 300_000 gwei, 10_000 gwei, 10_000 gwei, 10_000 gwei, 1_000 gwei
        );
        ZkBobAccounting(_accounting).setLimits(
            1, 2_000_000 gwei, 300_000 gwei, 300_000 gwei, 100_000 gwei, 100_000 gwei, 10_000 gwei, 1_000 gwei
        );
        ZkBobAccounting(_accounting).setLimits(
            254, 2_000_000 gwei, 300_000 gwei, 300_000 gwei, 20_000 gwei, 20_000 gwei, 10_000 gwei, 1_000 gwei
        );
    }

    function _load(bytes memory _dump, uint256 _from, uint256 _len) internal returns (uint256 res) {
        assembly {
            res := shr(sub(256, shl(3, _len)), mload(add(_dump, add(32, _from))))
        }
    }
}

contract DeployZkBobPoolModules is Script, Test {
    function run() external {
        ZkBobPoolUSDC pool = ZkBobPoolUSDC(address(zkBobPool));
        address owner = pool.owner();
        vm.etch(owner, type(DummyDelegateCall).runtimeCode);

        address tokenSeller = address(pool.tokenSeller());
        uint256 poolIndex = uint256(pool.pool_index());

        vm.startBroadcast();

        ZkBobPoolUSDC impl = new ZkBobPoolUSDC(
            pool.pool_id(),
            pool.token(),
            pool.transfer_verifier(),
            pool.tree_verifier(),
            pool.batch_deposit_verifier(),
            address(pool.direct_deposit_queue())
        );
        Migrator mig = new Migrator();
        ZkBobAccounting acc = new ZkBobAccounting(address(pool), 1_000_000_000);
        acc.transferOwnership(owner);
        DummyDelegateCall(owner).delegate(
            address(mig), abi.encodeWithSelector(Migrator.migrate.selector, address(pool), address(impl), address(acc))
        );

        vm.stopBroadcast();

        acc.slot0();
        acc.slot1();

        assertEq(address(pool.tokenSeller()), tokenSeller);
        assertEq(uint256(pool.pool_index()), poolIndex);
    }
}
