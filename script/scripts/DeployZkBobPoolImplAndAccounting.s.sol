// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import {console, Script} from "forge-std/Script.sol";
import {ZkBobPoolUSDC} from "../../src/zkbob/ZkBobPoolUSDC.sol";
import {ZkBobAccounting} from "../../src/zkbob/utils/ZkBobAccounting.sol";
import {EIP1967Proxy} from "../../src/proxy/EIP1967Proxy.sol";

/**
 * @dev OP-USDC pool proxy address.
 */
address constant zkBobPool = 0x1CA8C2B9B20E18e86d5b9a72370fC6c91814c97C;

/**
 * @dev The address of the timelock
 */
address constant zkBobTimelock = 0xbe7D4E55D80fC3e67D80ebf988eB0E551cCA4eB7;

/**
 * @dev Don't forget to set ZkBobPool.TOKEN_NUMERATOR to 1000 for USDC pools.
 */
contract DeployZkBobPoolImplAndAccounting is Script {
    function run() external {
        ZkBobPoolUSDC pool = ZkBobPoolUSDC(address(zkBobPool));

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

        // 2. Deploy new ZkBobAccounting implementation
        ZkBobAccounting accounting = new ZkBobAccounting(address(pool), 1_000_000_000);

        // 3. Set timelock as the owner of the accounting
        accounting.transferOwnership(zkBobTimelock);

        vm.stopBroadcast();

        assert(accounting.owner() == zkBobTimelock);

        console.log("ZkBobPool implementation:", address(newImpl));
        console.log("ZkBobAccounting: ", address(accounting));
    }
}
