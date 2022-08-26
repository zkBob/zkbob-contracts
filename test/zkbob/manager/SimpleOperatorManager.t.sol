// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../../shared/Env.t.sol";
import "../../../src/zkbob/manager/SimpleOperatorManager.sol";

contract SimpleOperatorManagerTest is Test {
    function testSimpleOperatorChanges() public {
        SimpleOperatorManager manager = new SimpleOperatorManager(user1, user3, "https://user1.example.com");

        assertEq(manager.operator(), user1);
        assertEq(manager.operatorURI(), "https://user1.example.com");
        assertEq(manager.isOperator(user1), true);
        assertEq(manager.isOperator(user2), false);
        assertTrue(manager.isOperatorFeeReceiver(user1, user3));
        assertTrue(!manager.isOperatorFeeReceiver(user1, user2));
        assertTrue(!manager.isOperatorFeeReceiver(user2, user3));
    }

    function testEnableForAll() public {
        SimpleOperatorManager manager = new SimpleOperatorManager(address(0), address(0), "");

        assertEq(manager.operator(), address(0));
        assertEq(manager.operatorURI(), "");
        assertEq(manager.isOperator(user1), true);
        assertEq(manager.isOperator(user2), true);
        assertTrue(!manager.isOperatorFeeReceiver(user1, user3));
    }
}
