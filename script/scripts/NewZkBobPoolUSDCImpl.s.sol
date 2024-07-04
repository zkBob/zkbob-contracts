// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "../../src/zkbob/ZkBobPoolUSDC.sol";

/**
 * @dev OP-USDC pool proxy address.
 */
address constant zkBobPool = 0x1CA8C2B9B20E18e86d5b9a72370fC6c91814c97C;

contract DeployNewZkBobPoolUSDCImpl is Script {
    function run() external {
        ZkBobPoolUSDC pool = ZkBobPoolUSDC(payable(zkBobPool));

        vm.startBroadcast();

        ZkBobPoolUSDC newImpl = new ZkBobPoolUSDC(
            pool.pool_id(),
            pool.token(),
            pool.transfer_verifier(),
            pool.tree_verifier(),
            pool.batch_deposit_verifier(),
            address(pool.direct_deposit_queue())
        );

        vm.stopBroadcast();

        console2.log("ZkBobPoolUSDC implementation:", address(newImpl));
    }
}
