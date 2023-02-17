// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPool.sol";
import "../../src/zkbob/manager/MutableOperatorManager.sol";

contract DeployNewZkBobPoolImpl is Script {
    function run() external {
        vm.startBroadcast();

        ZkBobPool pool = ZkBobPool(zkBobPool);

        ZkBobPool impl = new ZkBobPool(
            pool.pool_id(),
            pool.token(),
            pool.transfer_verifier(),
            pool.tree_verifier(),
            pool.batch_deposit_verifier(),
            address(pool.direct_deposit_queue())
        );

        vm.stopBroadcast();

        console2.log("ZkBobPool implementation:", address(impl));
    }
}
