// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import {AllowListOperatorManager} from "../../src/zkbob/manager/AllowListOperatorManager.sol";

// TODO: Update this values before the deployment
address constant operatorManagerOwner = 0x14fc6a1a996A2EB889cF86e5c8cD17323bC85290;
address constant zkBobProxy1 = 0x7D2D146a7AD3F0Dc398AA718a9bFCa2Bc873a5FD;
address constant zkBobProxyFeeReceiver1 = 0x7D2D146a7AD3F0Dc398AA718a9bFCa2Bc873a5FD;
address constant zkBobProxy2 = 0xFec49782FE8e11De9Fb3Ba645a76FE914FFfe3cb;
address constant zkBobProxyFeeReceiver2 = 0xFec49782FE8e11De9Fb3Ba645a76FE914FFfe3cb;
address constant zkBobProver1 = 0x33a0b018340d6424870cfC686a4d02e1df792254;
address constant zkBobProverFeeReceiver1 = 0x33a0b018340d6424870cfC686a4d02e1df792254;
address constant zkBobProver2 = 0x63A88E69fa7adEf036fc6ED94394CC9295de2f99;
address constant zkBobProverFeeReceiver2 = 0x63A88E69fa7adEf036fc6ED94394CC9295de2f99;

bool constant allowListEnabled = true;

contract DeployAllowListOperatorManager is Script {
    function run() external {
        vm.startBroadcast();

        address[] memory operators = new address[](4);
        operators[0] = zkBobProxy1;
        operators[1] = zkBobProver1;
        operators[2] = zkBobProxy2;
        operators[3] = zkBobProver2;

        address[] memory feeReceivers = new address[](4);
        feeReceivers[0] = zkBobProxyFeeReceiver1;
        feeReceivers[1] = zkBobProverFeeReceiver1;
        feeReceivers[2] = zkBobProxyFeeReceiver2;
        feeReceivers[3] = zkBobProverFeeReceiver2;

        AllowListOperatorManager operatorManager =
            new AllowListOperatorManager(operators, feeReceivers, allowListEnabled);

        operatorManager.transferOwnership(operatorManagerOwner);

        vm.stopBroadcast();

        assert(address(operatorManager.owner()) == operatorManagerOwner);

        console2.log("AllowListOperatorManager address:", address(operatorManager));
    }
}
