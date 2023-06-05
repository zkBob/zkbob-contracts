// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../src/zkbob/ZkBobPoolBOB.sol";

contract DeployNewZkBobPoolBOBImpl is Script {
    function run() external {
        vm.startBroadcast();

        ZkBobPoolBOB pool = ZkBobPoolBOB(zkBobPool);

        ZkBobPoolBOB impl = new ZkBobPoolBOB(
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
