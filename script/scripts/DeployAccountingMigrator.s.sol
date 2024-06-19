// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import {console, Script} from "forge-std/Script.sol";
import {ZkBobPool, ZkBobPoolUSDC} from "../../src/zkbob/ZkBobPoolUSDC.sol";
import {IZkBobAccounting, IKycProvidersManager, ZkBobAccounting} from "../../src/zkbob/utils/ZkBobAccounting.sol";
import {EIP1967Proxy} from "../../src/proxy/EIP1967Proxy.sol";

contract AccountingMigrator {
    constructor() {}

    // TODO: Check limits
    function migrate(
        address _pool,
        address _accounting,
        address _kycManager,
        address _accountingOwner,
        address _proxyAdmin
    )
        external
    {
        ZkBobAccounting accounting = ZkBobAccounting(_accounting);

        bytes memory dump = ZkBobPool(_pool).extsload(bytes32(uint256(1)), 2);
        uint32 txCount = uint32(_load(dump, 0, 4));
        uint88 cumTvl = uint88(_load(dump, 4, 11));
        uint32 maxWeeklyTxCount = uint32(_load(dump, 21, 4));
        uint56 maxWeeklyAvgTvl = uint56(_load(dump, 25, 7));
        uint72 tvl = uint72(_load(dump, 55, 9));

        ZkBobPool(_pool).initializePoolIndex(txCount * 128);
        ZkBobPool(_pool).setAccounting(IZkBobAccounting(accounting));

        accounting.initialize(txCount, tvl, cumTvl, maxWeeklyTxCount, maxWeeklyAvgTvl);
        accounting.setKycProvidersManager(IKycProvidersManager(_kycManager));
        accounting.setLimits(
            0, 2_000_000 gwei, 300_000 gwei, 300_000 gwei, 10_000 gwei, 10_000 gwei, 10_000 gwei, 1_000 gwei
        );
        accounting.setLimits(
            1, 2_000_000 gwei, 300_000 gwei, 300_000 gwei, 100_000 gwei, 100_000 gwei, 10_000 gwei, 1_000 gwei
        );
        accounting.setLimits(
            254, 2_000_000 gwei, 300_000 gwei, 300_000 gwei, 20_000 gwei, 20_000 gwei, 10_000 gwei, 1_000 gwei
        );

        accounting.transferOwnership(_accountingOwner);
        EIP1967Proxy(payable(address(_pool))).setAdmin(_proxyAdmin);
    }

    function _load(bytes memory _dump, uint256 _from, uint256 _len) internal pure returns (uint256 res) {
        assembly {
            res := shr(sub(256, shl(3, _len)), mload(add(_dump, add(32, _from))))
        }
    }
}

contract DeployAccountingMigrator is Script {
    function run() external {
        vm.startBroadcast();
        AccountingMigrator migrator = new AccountingMigrator();
        vm.stopBroadcast();

        console.log("AccountingMigrator: ", address(migrator));
    }
}
