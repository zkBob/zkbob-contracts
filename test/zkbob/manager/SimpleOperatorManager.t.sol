// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../../../src/zkbob/manager/SimpleOperatorManager.sol";

contract SimpleOperatorManagerTest is Test {
    address user1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address user2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address user3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    function testSimpleOperatorChanges() public {
        SimpleOperatorManager manager = new SimpleOperatorManager(user1, "https://user1.example.com");

        assertEq(manager.operator(), user1);
        assertEq(manager.operatorURI(), "https://user1.example.com");
        assertEq(manager.isOperator(user1), true);
        assertEq(manager.isOperator(user2), false);
    }

    function testEnableForAll() public {
        SimpleOperatorManager manager = new SimpleOperatorManager(address(0), "");

        assertEq(manager.operator(), address(0));
        assertEq(manager.operatorURI(), "");
        assertEq(manager.isOperator(user1), true);
        assertEq(manager.isOperator(user2), true);
    }
}
