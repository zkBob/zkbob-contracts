// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPool.sol";
import "../../src/zkbob/manager/MutableOperatorManager.sol";
import "../../src/zkbob/ZkBobPoolETH.sol";

contract DeployNewZkBobPoolETHImpl is Script {
    function run() external {
        vm.startBroadcast();

        ZkBobPoolETH pool = ZkBobPoolETH(zkBobPool);

        ZkBobPoolETH impl = new ZkBobPoolETH(
            pool.pool_id(),
            pool.token(),
            pool.transfer_verifier(),
            pool.tree_verifier(),
            pool.batch_deposit_verifier(),
            address(pool.direct_deposit_queue()),
            address(pool.permit2)
        );

        vm.stopBroadcast();

        console2.log("ZkBobPoolETH implementation:", address(impl));
    }
}
