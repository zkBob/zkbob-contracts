// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPool.sol";
import "../../src/zkbob/manager/MutableOperatorManager.sol";
import "../../src/zkbob/ZkBobPoolERC20.sol";

contract DeployNewZkBobPoolERC20Impl is Script {
    function run() external {
        vm.startBroadcast();

        ZkBobPoolERC20 pool = ZkBobPoolERC20(zkBobPool);

        ZkBobPoolERC20 impl = new ZkBobPoolERC20(
            pool.pool_id(),
            pool.token(),
            pool.transfer_verifier(),
            pool.tree_verifier(),
            pool.batch_deposit_verifier(),
            address(pool.direct_deposit_queue())
        );

        vm.stopBroadcast();

        console2.log("ZkBobPoolERC20 implementation:", address(impl));
    }
}
