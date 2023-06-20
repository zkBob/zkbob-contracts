// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../src/KYCToken.sol";

contract DeployKYCToken is Script {
    function run() external {
        require(tx.origin == deployer, "Script private key is different from deployer address");

        vm.startBroadcast();

        KYCToken token = new KYCToken();

        console2.log("KYCToken:", address(token));
    }
}
