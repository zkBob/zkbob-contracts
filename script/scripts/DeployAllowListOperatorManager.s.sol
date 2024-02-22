// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import {AllowListOperatorManager} from "../../src/zkbob/manager/AllowListOperatorManager.sol";

contract DeployAllowListOperatorManager is Script {
    function run() external {
        vm.startBroadcast();

        address[] memory operators = new address[](1);
        operators[0] = zkBobRelayer;

        address[] memory feeReceivers = new address[](1);
        feeReceivers[0] = zkBobRelayerFeeReceiver;

        AllowListOperatorManager operatorManager =
            new AllowListOperatorManager(operators, feeReceivers, allowListEnabled);

        vm.stopBroadcast();

        console2.log("AllowListOperatorManager address:", address(operatorManager));
    }
}
