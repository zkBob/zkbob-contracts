// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import {AllowListOperatorManager} from "../../src/zkbob/manager/AllowListOperatorManager.sol";

contract DeployAllowListOperatorManager is Script {
    function run() external {
        vm.startBroadcast();

        address[] memory operators = new address[](2);
        operators[0] = zkBobProxy;
        operators[1] = zkBobProver;

        address[] memory feeReceivers = new address[](2);
        feeReceivers[0] = zkBobProxyFeeReceiver;
        feeReceivers[1] = zkBobProverFeeReceiver;

        AllowListOperatorManager operatorManager =
            new AllowListOperatorManager(operators, feeReceivers, allowListEnabled);

        vm.stopBroadcast();

        console2.log("AllowListOperatorManager address:", address(operatorManager));
    }
}
