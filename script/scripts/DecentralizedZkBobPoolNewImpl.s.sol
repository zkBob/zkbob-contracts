// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./DecentralizedEnv.s.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobDirectDepositQueue.sol";
import "../../src/zkbob/ZkBobDirectDepositQueueETH.sol";
import "../../src/zkbob/manager/AllowListOperatorManager.sol";
import "../../src/zkbob/ZkBobPoolBOB.sol";
import "../../src/zkbob/ZkBobPoolETH.sol";
import "../../src/zkbob/ZkBobPoolUSDC.sol";
import "../../src/zkbob/ZkBobPoolERC20.sol";
import "../../src/zkbob/utils/ZkBobAccounting.sol";

contract DeployZkBobPoolNewImpl is Script {

    function run() external {
        address zkBobPool = 0x77f3D9Fb578a0F2B300347fb3Cd302dFd7eedf93;

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

        console2.log("ZkBobPoolBob implementation:", address(impl));
    }
}