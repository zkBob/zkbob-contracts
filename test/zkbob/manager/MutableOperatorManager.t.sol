// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../../shared/Env.t.sol";
import "../../../src/zkbob/manager/MutableOperatorManager.sol";

contract MutableOperatorManagerTest is Test {
    function testSimpleOperatorChanges() public {
        MutableOperatorManager manager = new MutableOperatorManager(user1, "https://user1.example.com");

        assertEq(manager.owner(), address(this));
        manager.transferOwnership(user3);
        assertEq(manager.owner(), user3);

        assertEq(manager.operator(), user1);
        assertEq(manager.operatorURI(), "https://user1.example.com");
        assertEq(manager.isOperator(user1), true);
        assertEq(manager.isOperator(user2), false);

        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        manager.setOperator(user2, "https://user2.example.com");
        vm.prank(user3);
        manager.setOperator(user2, "https://user2.example.com");
        assertEq(manager.operator(), user2);
        assertEq(manager.operatorURI(), "https://user2.example.com");
        assertEq(manager.isOperator(user1), false);
        assertEq(manager.isOperator(user2), true);
    }

    function testEnableForAll() public {
        MutableOperatorManager manager = new MutableOperatorManager(user1, "https://user1.example.com");

        manager.setOperator(address(0), "");
        assertEq(manager.operator(), address(0));
        assertEq(manager.operatorURI(), "");
        assertEq(manager.isOperator(user1), true);
        assertEq(manager.isOperator(user2), true);
    }
}
