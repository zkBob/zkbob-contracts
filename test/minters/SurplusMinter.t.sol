// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../shared/Env.t.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/BobToken.sol";
import "../../src/minters/SurplusMinter.sol";

contract SurplusMinterTest is Test {
    BobToken bob;
    SurplusMinter minter;

    event WithdrawSurplus(address indexed to, uint256 realized, uint256 unrealized);
    event AddSurplus(address indexed from, uint256 surplus);

    function setUp() public {
        EIP1967Proxy bobProxy = new EIP1967Proxy(address(this), mockImpl, "");
        BobToken bobImpl = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(bobImpl));
        bob = BobToken(address(bobProxy));

        minter = new SurplusMinter(address(bob));

        bob.updateMinter(address(minter), true, true);
        bob.updateMinter(address(this), true, true);

        minter.setMinter(address(this), true);
    }

    function testSurplusAdd() public {
        vm.prank(user1);
        vm.expectRevert("SurplusMinter: not a minter");
        minter.add(100 ether);

        vm.expectEmit(true, false, false, true);
        emit AddSurplus(address(this), 100 ether);
        minter.add(100 ether);
        assertEq(minter.surplus(), 100 ether);
    }

    function testSurplusBurn() public {
        minter.add(100 ether);

        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        minter.burn(100 ether);

        vm.expectRevert("SurplusMinter: exceeds surplus");
        minter.burn(2000 ether);

        vm.expectEmit(true, false, false, true);
        emit WithdrawSurplus(address(0), 0, 60 ether);
        minter.burn(60 ether);
        assertEq(minter.surplus(), 40 ether);
        minter.burn(40 ether);
        assertEq(minter.surplus(), 0 ether);
    }

    function testSurplusWithdraw() public {
        minter.add(100 ether);
        bob.mint(address(minter), 50 ether);

        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        minter.withdraw(user1, 100 ether);

        vm.expectRevert("SurplusMinter: exceeds surplus");
        minter.withdraw(user1, 200 ether);

        vm.expectEmit(true, false, false, true);
        emit WithdrawSurplus(user1, 30 ether, 0 ether);
        minter.withdraw(user1, 30 ether);
        assertEq(minter.surplus(), 70 ether);
        assertEq(bob.balanceOf(user1), 30 ether);
        assertEq(bob.balanceOf(address(minter)), 20 ether);

        vm.expectEmit(true, false, false, true);
        emit WithdrawSurplus(user1, 20 ether, 10 ether);
        minter.withdraw(user1, 30 ether);
        assertEq(minter.surplus(), 40 ether);
        assertEq(bob.balanceOf(user1), 60 ether);
        assertEq(bob.balanceOf(address(minter)), 0 ether);

        vm.expectEmit(true, false, false, true);
        emit WithdrawSurplus(user1, 0 ether, 40 ether);
        minter.withdraw(user1, 40 ether);
        assertEq(minter.surplus(), 0 ether);
        assertEq(bob.balanceOf(user1), 100 ether);
        assertEq(bob.balanceOf(address(minter)), 0 ether);
    }
}
