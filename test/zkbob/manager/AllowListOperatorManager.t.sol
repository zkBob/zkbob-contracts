// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import {Test} from "forge-std/Test.sol";
import {AllowListOperatorManager} from "../../../src/zkbob/manager/AllowListOperatorManager.sol";
import "../../shared/Env.t.sol";

contract AllowListOperatorManagerTest is Test {
    address operator1 = makeAddr("operator1");
    address feeReceiver1 = makeAddr("feeReceiver1");

    address operator2 = makeAddr("operator2");
    address feeReceiver2 = makeAddr("feeReceiver2");

    address unauthorized = makeAddr("unauthorized");
    address unauthorizedFeeReceiver = makeAddr("unauthorizedFeeReceiver");

    AllowListOperatorManager manager;

    function testConstructor() public {
        address[] memory operators = new address[](2);
        operators[0] = operator1;
        operators[1] = operator2;

        address[] memory feeReceivers = new address[](1);
        feeReceivers[0] = feeReceiver1;

        vm.expectRevert("AllowListOperatorManager: arrays length mismatch");
        manager = new AllowListOperatorManager(operators, feeReceivers, true);

        feeReceivers = new address[](2);
        feeReceivers[0] = feeReceiver1;
        feeReceivers[1] = feeReceiver2;
        operators[0] = address(0);

        vm.expectRevert("AllowListOperatorManager: zero address");
        manager = new AllowListOperatorManager(operators, feeReceivers, true);

        operators[0] = operator1;
        manager = new AllowListOperatorManager(operators, feeReceivers, true);
        assertEq(manager.owner(), address(this));

        assertTrue(manager.isOperator(operator1));
        assertTrue(manager.isOperatorFeeReceiver(operator1, feeReceiver1));
        
        assertTrue(manager.isOperator(operator2));
        assertTrue(manager.isOperatorFeeReceiver(operator2, feeReceiver2));
        
        assertFalse(manager.isOperator(unauthorized));
        assertFalse(manager.isOperator(address(this)));

        // TODO:
        manager = new AllowListOperatorManager(operators, feeReceivers, false);
        assertEq(manager.owner(), address(this));
        
        assertTrue(manager.isOperator(operator1));
        assertTrue(manager.isOperator(operator2));
        assertTrue(manager.isOperator(unauthorized));
        assertTrue(manager.isOperator(makeAddr("random")));
    }
}