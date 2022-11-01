// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../shared/Env.t.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/BobToken.sol";
import "../../src/minters/BalancedMinter.sol";

contract BalancedMinterTest is Test {
    BobToken bob;
    BalancedMinter minter;

    function setUp() public {
        EIP1967Proxy bobProxy = new EIP1967Proxy(address(this), mockImpl, "");
        BobToken bobImpl = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(bobImpl));
        bob = BobToken(address(bobProxy));

        minter = new BalancedMinter(address(bob), 200 ether, 100 ether);

        bob.updateMinter(address(minter), true, true);
        bob.updateMinter(address(this), true, true);
    }

    function testMintPermissions() public {
        vm.expectRevert("BaseMinter: not a minter");
        minter.mint(user3, 1 ether);
        vm.expectRevert("BaseMinter: not a burner");
        minter.burn(1 ether);

        vm.startPrank(deployer);
        vm.expectRevert("Ownable: caller is not the owner");
        minter.setMinter(deployer, true);
        vm.expectRevert("Ownable: caller is not the owner");
        minter.adjustQuotas(200 ether, 100 ether);
        vm.stopPrank();

        minter.setMinter(deployer, true);
        minter.adjustQuotas(200 ether, 100 ether);

        vm.expectRevert("BaseMinter: not a minter");
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

        vm.expectRevert("BalancedMinter: exceeds minting quota");
        minter.mint(address(this), 300 ether);
        minter.mint(address(this), 200 ether);

        bob.transfer(address(minter), 200 ether);
        minter.burn(200 ether);

        assertEq(minter.mintQuota(), 200 ether);
        assertEq(minter.burnQuota(), 100 ether);

        bob.transfer(address(minter), 200 ether);
        vm.expectRevert("BalancedMinter: exceeds burning quota");
        minter.burn(200 ether);
        minter.burn(100 ether);
    }

    function testBurnWithTransferAndCall() public {
        bob.mint(address(this), 200 ether);
        bob.mint(user1, 200 ether);
        minter.setMinter(address(this), true);

        vm.prank(user1);
        vm.expectRevert("BaseMinter: not a burner");
        bob.transferAndCall(address(minter), 10 ether, "");
        vm.expectRevert("BalancedMinter: exceeds burning quota");
        bob.transferAndCall(address(minter), 110 ether, "");
        bob.transferAndCall(address(minter), 10 ether, "");

        assertEq(minter.mintQuota(), 210 ether);
        assertEq(minter.burnQuota(), 90 ether);
    }

    function testBurnFrom() public {
        bob.mint(address(this), 200 ether);
        bob.mint(user1, 200 ether);
        minter.setMinter(address(this), true);

        vm.expectRevert("ERC20: insufficient allowance");
        minter.burnFrom(user1, 10 ether);

        vm.prank(user1);
        bob.approve(address(minter), 110 ether);

        vm.expectRevert("BalancedMinter: exceeds burning quota");
        minter.burnFrom(user1, 110 ether);
        minter.burnFrom(user1, 10 ether);

        assertEq(minter.mintQuota(), 210 ether);
        assertEq(minter.burnQuota(), 90 ether);
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

        assertEq(minter.mintQuota(), -10 ether);
        assertEq(minter.burnQuota(), -110 ether);

        minter.adjustQuotas(200 ether, 100 ether);

        assertEq(minter.mintQuota(), 190 ether);
        assertEq(minter.burnQuota(), -10 ether);
    }

    function _setupDualMinter() internal returns (BalancedMinter) {
        BalancedMinter minter2 = new BalancedMinter(address(bob), 100 ether, 200 ether);
        minter.setMinter(address(this), true);
        minter2.setMinter(address(this), true);
        bob.updateMinter(address(minter2), true, true);
        bob.mint(address(minter), 1000 ether);
        bob.mint(address(minter2), 1000 ether);
        return minter2;
    }

    function testMultiChain() public {
        BalancedMinter minter2 = _setupDualMinter();

        minter.burn(60 ether); // 200/100 -> 260/40
        minter2.mint(user1, 60 ether); // 100/200 -> 40/260

        vm.expectRevert("BalancedMinter: exceeds burning quota");
        minter.burn(60 ether);

        minter2.adjustQuotas(50 ether, -50 ether); // 40/260 -> 90/210
        minter.adjustQuotas(-50 ether, 50 ether); // 260/40 -> 210/90

        minter.burn(60 ether); // 210/90 -> 270/30
        minter2.mint(user1, 60 ether); // 90/210 -> 30/270

        minter2.burn(250 ether); // 30/270 -> 280/20
        minter2.adjustQuotas(50 ether, -50 ether); // 280/20 -> 330/-30
        minter.mint(user1, 250 ether); // 270/30 -> 20/280
        minter.adjustQuotas(-50 ether, 50 ether); // -30/330

        minter.burn(100 ether); // -30/330 -> 70/230
        minter2.mint(user1, 100 ether); // 330/-30 -> 230/70

        assertEq(minter.mintQuota(), 70 ether);
        assertEq(minter.burnQuota(), 230 ether);
        assertEq(minter2.mintQuota(), 230 ether);
        assertEq(minter2.burnQuota(), 70 ether);
    }

    function testStuckFailedMint() public {
        BalancedMinter minter2 = _setupDualMinter();

        // burn is executed before first gov limits adjustment is made
        minter2.burn(160 ether); // 100/200 -> 260/40
        // this leads to a negative burn quota
        minter2.adjustQuotas(50 ether, -50 ether); // 260/40 -> 310/-10
        // second gov limits adjustment is executed before mint
        minter.adjustQuotas(-50 ether, 50 ether); // 200/100 -> 150/150
        // mint fails, as the quota was already adjusted
        vm.expectRevert("BalancedMinter: exceeds minting quota");
        minter.mint(user1, 160 ether);

        // resolve failed mint manually
        minter.adjustQuotas(-160 ether, 160 ether); // 150/150 -> -10/310
        bob.mint(user1, 160 ether);

        assertEq(minter.mintQuota(), -10 ether);
        assertEq(minter.burnQuota(), 310 ether);
        assertEq(minter2.mintQuota(), 310 ether);
        assertEq(minter2.burnQuota(), -10 ether);
    }
}
