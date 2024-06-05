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

        vm.expectRevert("OperatorManager: arrays length mismatch");
        manager = new AllowListOperatorManager(operators, feeReceivers, true);

        feeReceivers = new address[](2);
        feeReceivers[0] = feeReceiver1;
        feeReceivers[1] = feeReceiver2;
        operators[0] = address(0);

        vm.expectRevert("OperatorManager: zero address");
        manager = new AllowListOperatorManager(operators, feeReceivers, true);

        operators[0] = operator1;
        manager = new AllowListOperatorManager(operators, feeReceivers, true);
        assertEq(manager.owner(), address(this));
        assertTrue(manager.allowListEnabled());

        assertTrue(manager.isOperator(operator1));
        assertTrue(manager.isOperatorFeeReceiver(operator1, feeReceiver1));

        assertTrue(manager.isOperator(operator2));
        assertTrue(manager.isOperatorFeeReceiver(operator2, feeReceiver2));

        assertFalse(manager.isOperator(unauthorized));
        assertFalse(manager.isOperator(address(this)));

        manager = new AllowListOperatorManager(operators, feeReceivers, false);
        assertEq(manager.owner(), address(this));
        assertFalse(manager.allowListEnabled());

        assertTrue(manager.isOperator(operator1));
        assertTrue(manager.isOperatorFeeReceiver(operator1, feeReceiver1));
        assertTrue(manager.isOperator(operator2));
        assertTrue(manager.isOperatorFeeReceiver(operator2, feeReceiver2));

        assertTrue(manager.isOperator(unauthorized));
        assertTrue(manager.isOperator(makeAddr("random")));
    }

    function testOperatorURI() public {
        manager = new AllowListOperatorManager(new address[](0), new address[](0), true);
        assertEq(manager.operatorURI(), "");
    }

    function testSetAllowListEnabled() public {
        address[] memory operators = new address[](2);
        operators[0] = operator1;
        operators[1] = operator2;

        address[] memory feeReceivers = new address[](2);
        feeReceivers[0] = feeReceiver1;
        feeReceivers[1] = feeReceiver2;

        manager = new AllowListOperatorManager(operators, feeReceivers, true);
        assertTrue(manager.allowListEnabled());
        assertTrue(manager.isOperator(operator1));
        assertTrue(manager.isOperatorFeeReceiver(operator1, feeReceiver1));
        assertTrue(manager.isOperator(operator2));
        assertTrue(manager.isOperatorFeeReceiver(operator2, feeReceiver2));
        assertFalse(manager.isOperator(unauthorized));

        vm.prank(makeAddr("not owner"));
        vm.expectRevert("Ownable: caller is not the owner");
        manager.setAllowListEnabled(false);

        manager.setAllowListEnabled(false);
        assertFalse(manager.allowListEnabled());
        assertTrue(manager.isOperator(unauthorized));

        manager.setAllowListEnabled(true);
        assertTrue(manager.allowListEnabled());
        assertTrue(manager.isOperator(operator1));
        assertTrue(manager.isOperatorFeeReceiver(operator1, feeReceiver1));
        assertTrue(manager.isOperator(operator2));
        assertTrue(manager.isOperatorFeeReceiver(operator2, feeReceiver2));
        assertFalse(manager.isOperator(unauthorized));
    }

    function testSetOperator() public {
        address[] memory operators = new address[](1);
        operators[0] = operator1;

        address[] memory feeReceivers = new address[](1);
        feeReceivers[0] = feeReceiver1;

        manager = new AllowListOperatorManager(operators, feeReceivers, true);
        assertTrue(manager.isOperator(operator1));
        assertTrue(manager.isOperatorFeeReceiver(operator1, feeReceiver1));
        assertFalse(manager.isOperator(operator2));
        assertFalse(manager.isOperatorFeeReceiver(operator2, feeReceiver2));

        vm.prank(makeAddr("not owner"));
        vm.expectRevert("Ownable: caller is not the owner");
        manager.setOperator(operator2, feeReceiver2, true);

        manager.setOperator(operator2, feeReceiver2, true);
        assertTrue(manager.isOperator(operator2));
        assertTrue(manager.isOperatorFeeReceiver(operator2, feeReceiver2));

        manager.setOperator(operator1, feeReceiver1, false);
        assertFalse(manager.isOperator(operator1));
        // Even if operator was removed, we still allow to claim accumulated fees
        assertTrue(manager.isOperatorFeeReceiver(operator1, feeReceiver1));

        manager.setOperator(operator1, feeReceiver1, true);
        assertTrue(manager.isOperator(operator1));
        assertTrue(manager.isOperatorFeeReceiver(operator1, feeReceiver1));
        assertTrue(manager.isOperator(operator2));
        assertTrue(manager.isOperatorFeeReceiver(operator2, feeReceiver2));
        assertFalse(manager.isOperator(unauthorized));
    }

    function testSetOperators() public {
        address[] memory operators = new address[](1);
        operators[0] = operator1;

        address[] memory feeReceivers = new address[](1);
        feeReceivers[0] = feeReceiver1;

        manager = new AllowListOperatorManager(operators, feeReceivers, true);
        assertTrue(manager.isOperator(operator1));
        assertTrue(manager.isOperatorFeeReceiver(operator1, feeReceiver1));

        operators = new address[](2);
        operators[0] = operator1;
        operators[1] = operator2;

        feeReceivers = new address[](1);
        feeReceivers[0] = feeReceiver1;

        bool[] memory allowed = new bool[](2);
        allowed[0] = true;
        allowed[1] = true;

        vm.expectRevert("OperatorManager: arrays length mismatch");
        manager.setOperators(operators, allowed, feeReceivers);

        feeReceivers = new address[](2);
        feeReceivers[0] = feeReceiver1;
        feeReceivers[1] = feeReceiver2;

        allowed = new bool[](1);
        allowed[0] = true;

        vm.expectRevert("OperatorManager: arrays length mismatch");
        manager.setOperators(operators, allowed, feeReceivers);

        operators = new address[](10);
        operators[0] = operator1;
        feeReceivers = new address[](10);
        feeReceivers[0] = address(0);
        allowed = new bool[](10);
        for (uint256 i = 1; i < 10; i++) {
            operators[i] = address(uint160(i));
            feeReceivers[i] = address(uint160(2 * i + 1));
            allowed[i] = i % 2 != 0;
        }

        vm.prank(makeAddr("not owner"));
        vm.expectRevert("Ownable: caller is not the owner");
        manager.setOperators(operators, allowed, feeReceivers);

        manager.setOperators(operators, allowed, feeReceivers);
        for (uint256 i = 0; i < 10; i++) {
            assertEq(manager.isOperator(operators[i]), allowed[i]);
            if (i > 0) {
                assertEq(manager.isOperatorFeeReceiver(operators[i], feeReceivers[i]), allowed[i]);
            }
        }
        assertTrue(manager.isOperatorFeeReceiver(operator1, feeReceiver1));
    }

    function testSetFeeReceiver() public {
        address[] memory operators = new address[](1);
        operators[0] = operator1;

        address[] memory feeReceivers = new address[](1);
        feeReceivers[0] = feeReceiver1;

        manager = new AllowListOperatorManager(operators, feeReceivers, true);
        assertTrue(manager.isOperator(operator1));
        assertTrue(manager.isOperatorFeeReceiver(operator1, feeReceiver1));

        vm.prank(operator1);
        manager.setFeeReceiver(feeReceiver2);
        assertTrue(manager.isOperatorFeeReceiver(operator1, feeReceiver2));

        vm.prank(unauthorized);
        vm.expectRevert("OperatorManager: operator not allowed");
        manager.setFeeReceiver(unauthorizedFeeReceiver);
    }
}
