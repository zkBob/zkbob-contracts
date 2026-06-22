// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../src/zkbob/ZkBobPoolETH.sol";

contract DeployNewZkBobPoolETHImpl is Script {
    function run() external {
        vm.startBroadcast();

        ZkBobPoolETH pool = ZkBobPoolETH(payable(zkBobPool));

        ITransferVerifier transferVerifier;
        bytes memory code1 = vm.getCode(string.concat("out/prodV3/TransferVerifier.sol/TransferVerifier.json"));
        assembly {
            transferVerifier := create(0, add(code1, 0x20), mload(code1))
        }

        ZkBobPoolETH impl = new ZkBobPoolETH(
            pool.pool_id(),
            pool.token(),
            transferVerifier,
            pool.tree_verifier(),
            pool.batch_deposit_verifier(),
            address(pool.direct_deposit_queue()),
            address(pool.permit2())
        );

        vm.stopBroadcast();

        console2.log("TransferVerifier:", address(transferVerifier));
        console2.log("ZkBobPoolETH implementation:", address(impl));
    }
}
