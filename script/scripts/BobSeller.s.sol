// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../src/utils/UniswapV3Seller.sol";

contract DeployBobSeller is Script {
    function run() external {
        vm.startBroadcast();

        UniswapV3Seller seller = new UniswapV3Seller(uniV3Router, bobVanityAddr, fee0, usdc, fee1);

        vm.stopBroadcast();

        console2.log("BobSeller:", address(seller));
    }
}
