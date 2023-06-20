// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../shared/Env.t.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/BobToken.sol";
import "../../src/minters/DebtMinter.sol";

contract DebtMinterTest is Test {
    BobToken bob;
    DebtMinter minter;

    event UpdateDebt(uint104 debt, uint104 debtLimit);

    function setUp() public {
        EIP1967Proxy bobProxy = new EIP1967Proxy(address(this), mockImpl, "");
        BobToken bobImpl = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(bobImpl));
        bob = BobToken(address(bobProxy));

        minter = new DebtMinter(address(bob), 800 ether, 400 ether, 12 hours, 200 ether, user1);

        bob.updateMinter(address(minter), true, true);
        bob.updateMinter(address(this), true, true);

        minter.setMinter(address(this), true);

        vm.warp(block.timestamp + 1 days);

        vm.prank(user1);
        bob.approve(address(minter), 10000 ether);
        vm.prank(user2);
        bob.approve(address(minter), 10000 ether);
    }

    function testGetters() public {
        minter.mint(user1, 150 ether);

        assertEq(minter.getState().debt, 150 ether);
        assertEq(minter.getState().debtLimit, 400 ether);
        assertEq(minter.getState().lastRaise, 1);

        assertEq(minter.getParameters().maxDebtLimit, 800 ether);
        assertEq(minter.getParameters().minDebtLimit, 400 ether);
        assertEq(minter.getParameters().raiseDelay, 12 hours);
        assertEq(minter.getParameters().raise, 200 ether);
        assertEq(minter.getParameters().treasury, user1);
    }

    function testMintBurnBalanceChange() public {
        minter.mint(user1, 150 ether);
        assertEq(bob.balanceOf(user1), 150 ether);

        minter.burnFrom(user1, 50 ether);
        assertEq(bob.balanceOf(user1), 100 ether);

        vm.prank(user1);
        bob.transfer(address(minter), 50 ether);
        minter.burn(50 ether);
        assertEq(bob.balanceOf(user1), 50 ether);
        assertEq(bob.balanceOf(address(minter)), 0 ether);

        vm.prank(user1);
        bob.transfer(address(this), 50 ether);
        bob.transferAndCall(address(minter), 50 ether, "");
        assertEq(bob.balanceOf(user1), 0 ether);
        assertEq(bob.balanceOf(address(minter)), 0 ether);
    }

    function testSimpleDebtLimitIncrease() public {
        assertEq(minter.getState().debt, 0);
        assertEq(minter.getState().debtLimit, 400 ether);
        assertEq(minter.maxDebtIncrease(), 400 ether);

        minter.mint(user1, 150 ether);

        assertEq(minter.getState().debt, 150 ether);
        assertEq(minter.getState().debtLimit, 400 ether);
        assertEq(minter.maxDebtIncrease(), 250 ether);

        minter.mint(user1, 150 ether);

        assertEq(minter.getState().debt, 300 ether);
        assertEq(minter.getState().debtLimit, 400 ether);
        assertEq(minter.maxDebtIncrease(), 200 ether);

        minter.mint(user1, 150 ether);

        assertEq(minter.getState().debt, 450 ether);
        assertEq(minter.getState().debtLimit, 500 ether);
        assertEq(minter.maxDebtIncrease(), 50 ether);

        vm.expectRevert("DebtMinter: exceeds debt limit");
        minter.mint(user1, 150 ether);

        vm.warp(block.timestamp + 1 days);

        minter.mint(user1, 150 ether);
        assertEq(minter.getState().debt, 600 ether);
        assertEq(minter.getState().debtLimit, 650 ether);
        assertEq(minter.maxDebtIncrease(), 50 ether);

        vm.expectRevert("DebtMinter: exceeds debt limit");
        minter.mint(user1, 150 ether);

        vm.warp(block.timestamp + 1 days);

        minter.mint(user1, 150 ether);
        assertEq(minter.getState().debt, 750 ether);
        assertEq(minter.getState().debtLimit, 800 ether);
        assertEq(minter.maxDebtIncrease(), 50 ether);

        vm.warp(block.timestamp + 1 days);

        assertEq(minter.getState().debt, 750 ether);
        assertEq(minter.getState().debtLimit, 800 ether);
        assertEq(minter.maxDebtIncrease(), 50 ether);

        vm.expectRevert("DebtMinter: exceeds debt limit");
        minter.mint(user1, 51 ether);

        minter.mint(user1, 30 ether);

        assertEq(minter.getState().debt, 780 ether);
        assertEq(minter.getState().debtLimit, 800 ether);
        assertEq(minter.maxDebtIncrease(), 20 ether);

        vm.expectRevert("DebtMinter: exceeds debt limit");
        minter.mint(user1, 21 ether);

        minter.mint(user1, 20 ether);

        assertEq(minter.getState().debt, 800 ether);
        assertEq(minter.getState().debtLimit, 800 ether);
        assertEq(minter.maxDebtIncrease(), 0);
    }

    function testSimpleDebtLimitDecrease() public {
        minter.mint(user1, 400 ether);
        minter.mint(user1, 200 ether);
        vm.expectRevert("DebtMinter: exceeds debt limit");
        minter.mint(user1, 200 ether);
        vm.warp(block.timestamp + 1 days);
        minter.mint(user1, 200 ether);

        assertEq(minter.getState().debt, 800 ether);
        assertEq(minter.getState().debtLimit, 800 ether);
        assertEq(minter.maxDebtIncrease(), 0);

        minter.burnFrom(user1, 150 ether);

        assertEq(minter.getState().debt, 650 ether);
        assertEq(minter.getState().debtLimit, 800 ether);
        assertEq(minter.maxDebtIncrease(), 150 ether);

        minter.burnFrom(user1, 150 ether);

        assertEq(minter.getState().debt, 500 ether);
        assertEq(minter.getState().debtLimit, 700 ether);
        assertEq(minter.maxDebtIncrease(), 200 ether);
    }

    function testParamsIncrease() public {
        minter.mint(user1, 350 ether);
        minter.mint(user1, 100 ether);
        vm.warp(block.timestamp + 1 days);

        assertEq(minter.getState().debt, 450 ether);
        assertEq(minter.getState().debtLimit, 550 ether);
        assertEq(minter.maxDebtIncrease(), 200 ether);

        minter.updateParameters(DebtMinter.Parameters(1000 ether, 400 ether, 12 hours, 250 ether, user1));

        assertEq(minter.getState().debt, 450 ether);
        assertEq(minter.getState().debtLimit, 700 ether);
        assertEq(minter.maxDebtIncrease(), 250 ether);

        minter.updateParameters(DebtMinter.Parameters(2000 ether, 800 ether, 12 hours, 300 ether, user1));

        assertEq(minter.getState().debt, 450 ether);
        assertEq(minter.getState().debtLimit, 800 ether);
        assertEq(minter.maxDebtIncrease(), 350 ether);

        minter.mint(user1, 290 ether);

        assertEq(minter.getState().debt, 740 ether);
        assertEq(minter.getState().debtLimit, 800 ether);
        assertEq(minter.maxDebtIncrease(), 60 ether);

        vm.warp(block.timestamp + 1 days);

        assertEq(minter.getState().debt, 740 ether);
        assertEq(minter.getState().debtLimit, 800 ether);
        assertEq(minter.maxDebtIncrease(), 300 ether);

        minter.mint(user1, 10 ether);

        assertEq(minter.getState().debt, 750 ether);
        assertEq(minter.getState().debtLimit, 1040 ether);
        assertEq(minter.maxDebtIncrease(), 290 ether);

        minter.mint(user1, 250 ether);

        assertEq(minter.getState().debt, 1000 ether);
        assertEq(minter.getState().debtLimit, 1040 ether);
        assertEq(minter.maxDebtIncrease(), 40 ether);
    }

    function testParamsDecrease() public {
        minter.mint(user1, 350 ether);
        minter.mint(user1, 100 ether);
        vm.warp(block.timestamp + 1 days);

        assertEq(minter.getState().debt, 450 ether);
        assertEq(minter.getState().debtLimit, 550 ether);
        assertEq(minter.maxDebtIncrease(), 200 ether);

        minter.updateParameters(DebtMinter.Parameters(600 ether, 400 ether, 12 hours, 200 ether, user1));

        assertEq(minter.getState().debt, 450 ether);
        assertEq(minter.getState().debtLimit, 600 ether);
        assertEq(minter.maxDebtIncrease(), 150 ether);

        minter.updateParameters(DebtMinter.Parameters(500 ether, 400 ether, 12 hours, 100 ether, user1));

        assertEq(minter.getState().debt, 450 ether);
        assertEq(minter.getState().debtLimit, 500 ether);
        assertEq(minter.maxDebtIncrease(), 50 ether);

        vm.expectRevert("DebtMinter: exceeds debt limit");
        minter.mint(user1, 60 ether);
        minter.mint(user1, 50 ether);
        vm.warp(block.timestamp + 1 days);

        assertEq(minter.getState().debt, 500 ether);
        assertEq(minter.getState().debtLimit, 500 ether);
        assertEq(minter.maxDebtIncrease(), 0 ether);

        minter.burnFrom(user1, 50 ether);

        assertEq(minter.getState().debt, 450 ether);
        assertEq(minter.getState().debtLimit, 500 ether);
        assertEq(minter.maxDebtIncrease(), 50 ether);

        minter.updateParameters(DebtMinter.Parameters(300 ether, 200 ether, 12 hours, 100 ether, user1));

        assertEq(minter.getState().debt, 450 ether);
        assertEq(minter.getState().debtLimit, 450 ether);
        assertEq(minter.maxDebtIncrease(), 0 ether);

        minter.burnFrom(user1, 100 ether);

        assertEq(minter.getState().debt, 350 ether);
        assertEq(minter.getState().debtLimit, 350 ether);
        assertEq(minter.maxDebtIncrease(), 0 ether);

        minter.burnFrom(user1, 60 ether);

        assertEq(minter.getState().debt, 290 ether);
        assertEq(minter.getState().debtLimit, 300 ether);
        assertEq(minter.maxDebtIncrease(), 10 ether);

        minter.burnFrom(user1, 100 ether);

        assertEq(minter.getState().debt, 190 ether);
        assertEq(minter.getState().debtLimit, 290 ether);
        assertEq(minter.maxDebtIncrease(), 100 ether);

        minter.burnFrom(user1, 100 ether);

        assertEq(minter.getState().debt, 90 ether);
        assertEq(minter.getState().debtLimit, 200 ether);
        assertEq(minter.maxDebtIncrease(), 110 ether);

        minter.updateParameters(DebtMinter.Parameters(300 ether, 100 ether, 12 hours, 100 ether, user1));

        assertEq(minter.getState().debt, 90 ether);
        assertEq(minter.getState().debtLimit, 190 ether);
        assertEq(minter.maxDebtIncrease(), 100 ether);

        minter.updateParameters(DebtMinter.Parameters(0 ether, 0 ether, 12 hours, 0 ether, user1));

        assertEq(minter.getState().debt, 90 ether);
        assertEq(minter.getState().debtLimit, 90 ether);
        assertEq(minter.maxDebtIncrease(), 0 ether);

        minter.burnFrom(user1, 70 ether);

        assertEq(minter.getState().debt, 20 ether);
        assertEq(minter.getState().debtLimit, 20 ether);
        assertEq(minter.maxDebtIncrease(), 0 ether);

        minter.burnFrom(user1, 20 ether);

        assertEq(minter.getState().debt, 0 ether);
        assertEq(minter.getState().debtLimit, 0 ether);
        assertEq(minter.maxDebtIncrease(), 0 ether);
    }

    function testBurnExcess() public {
        minter.mint(user2, 350 ether);
        bob.mint(user2, 100 ether);

        assertEq(bob.totalSupply(), 450 ether);
        assertEq(bob.balanceOf(user2), 450 ether);
        assertEq(minter.getState().debt, 350 ether);
        assertEq(minter.getState().debtLimit, 400 ether);
        assertEq(minter.maxDebtIncrease(), 200 ether);

        minter.burnFrom(user2, 410 ether);

        assertEq(bob.totalSupply(), 100 ether);
        assertEq(bob.balanceOf(user2), 40 ether);
        assertEq(bob.balanceOf(user1), 60 ether);
        assertEq(minter.getState().debt, 0 ether);
        assertEq(minter.getState().debtLimit, 400 ether);
        assertEq(minter.maxDebtIncrease(), 400 ether);
    }

    function testDebtEmit() public {
        vm.expectEmit(true, false, false, true);
        emit UpdateDebt(350 ether, 400 ether);
        minter.mint(user1, 350 ether);

        vm.expectEmit(true, false, false, true);
        emit UpdateDebt(450 ether, 550 ether);
        minter.mint(user1, 100 ether);

        vm.warp(block.timestamp + 1 days);

        vm.expectEmit(true, false, false, true);
        emit UpdateDebt(420 ether, 620 ether);
        minter.burnFrom(user1, 30 ether);
    }
}
