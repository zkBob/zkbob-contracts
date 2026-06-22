// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../src/zkbob/ZkBobPoolUSDCMigrated.sol";

contract DeployNewZkBobPoolUSDCMigratedImpl is Script {
    function run() external {
        vm.startBroadcast();

        ZkBobPoolUSDCMigrated pool = ZkBobPoolUSDCMigrated(zkBobPool);

        ITransferVerifier transferVerifier;
        bytes memory code1 = vm.getCode(string.concat("out/prodV3/TransferVerifier.sol/TransferVerifier.json"));
        assembly {
            transferVerifier := create(0, add(code1, 0x20), mload(code1))
        }

        ZkBobPoolUSDCMigrated impl = new ZkBobPoolUSDCMigrated(
            pool.pool_id(),
            pool.token(),
            transferVerifier,
            pool.tree_verifier(),
            pool.batch_deposit_verifier(),
            address(pool.direct_deposit_queue())
        );

        vm.stopBroadcast();

        console2.log("TransferVerifier:", address(transferVerifier));
        console2.log("ZkBobPoolUSDCMigrated implementation:", address(impl));
    }
}
