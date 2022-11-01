// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../../shared/Env.t.sol";
import "../../../src/proxy/EIP1967Proxy.sol";
import "../../../src/BobToken.sol";
import "../../../src/utils/LimitedMinter.sol";

contract LimitedMinterTest is Test {
    BobToken bob;
    LimitedMinter minter;

    function setUp() public {
        EIP1967Proxy bobProxy = new EIP1967Proxy(address(this), mockImpl, "");
        BobToken bobImpl = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(bobImpl));
        bob = BobToken(address(bobProxy));

        minter = new LimitedMinter(address(bob), 200 ether, 100 ether);

        bob.updateMinter(address(minter), true, true);
        bob.updateMinter(address(this), true, true);
    }

    function testMintPermissions() public {
        vm.expectRevert("LimitedMinter: not a minter");
        minter.mint(user3, 1 ether);
        vm.expectRevert("LimitedMinter: not a burner");
        minter.burn(1 ether);

        vm.startPrank(deployer);
        vm.expectRevert("Ownable: caller is not the owner");
        minter.setMinter(deployer, true);
        vm.expectRevert("Ownable: caller is not the owner");
        minter.adjustQuotas(200 ether, 100 ether);
        vm.stopPrank();

        minter.setMinter(deployer, true);
        minter.adjustQuotas(200 ether, 100 ether);

        vm.expectRevert("LimitedMinter: not a minter");
        minter.mint(user1, 1 ether);

        vm.prank(deployer);
        minter.mint(user1, 1 ether);
    }

    function testQuotas() public {
        minter.setMinter(address(this), true);

        assertEq(minter.mintQuota(), 200 ether);
        assertEq(minter.burnQuota(), 100 ether);

        minter.mint(user1, 10 ether);

        assertEq(minter.mintQuota(), 190 ether);
        assertEq(minter.burnQuota(), 110 ether);

        vm.prank(user1);
        bob.transfer(address(minter), 5 ether);
        minter.burn(5 ether);

        assertEq(minter.mintQuota(), 195 ether);
        assertEq(minter.burnQuota(), 105 ether);
    }

    function testExceedingQuotas() public {
        bob.mint(address(this), 200 ether);
        minter.setMinter(address(this), true);

        vm.expectRevert("LimitedMinter: exceeds minting quota");
        minter.mint(address(this), 300 ether);
        minter.mint(address(this), 200 ether);

        bob.transfer(address(minter), 200 ether);
        minter.burn(200 ether);

        assertEq(minter.mintQuota(), 200 ether);
        assertEq(minter.burnQuota(), 100 ether);

        bob.transfer(address(minter), 200 ether);
        vm.expectRevert("LimitedMinter: exceeds burning quota");
        minter.burn(200 ether);
        minter.burn(100 ether);
    }

    function testBurnWithTransferAndCall() public {
        bob.mint(address(this), 200 ether);
        bob.mint(user1, 200 ether);
        minter.setMinter(address(this), true);

        vm.prank(user1);
        vm.expectRevert("LimitedMinter: not a burner");
        bob.transferAndCall(address(minter), 10 ether, "");
        vm.expectRevert("LimitedMinter: exceeds burning quota");
        bob.transferAndCall(address(minter), 110 ether, "");
        bob.transferAndCall(address(minter), 10 ether, "");
    }

    function testAdjustQuotas() public {
        assertEq(minter.mintQuota(), 200 ether);
        assertEq(minter.burnQuota(), 100 ether);

        minter.adjustQuotas(10 ether, -20 ether);

        assertEq(minter.mintQuota(), 210 ether);
        assertEq(minter.burnQuota(), 80 ether);

        minter.adjustQuotas(-20 ether, 10 ether);

        assertEq(minter.mintQuota(), 190 ether);
        assertEq(minter.burnQuota(), 90 ether);

        minter.adjustQuotas(-200 ether, -200 ether);

        assertEq(minter.mintQuota(), 0 ether);
        assertEq(minter.burnQuota(), 0 ether);

        minter.adjustQuotas(200 ether, 100 ether);

        assertEq(minter.mintQuota(), 200 ether);
        assertEq(minter.burnQuota(), 100 ether);
    }
}
