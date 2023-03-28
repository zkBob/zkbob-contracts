// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../shared/Env.t.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/BobToken.sol";
import "../../src/minters/FlashMinter.sol";
import "../mocks/ERC3156FlashBorrowerMock.sol";

contract FlashMinterTest is Test {
    BobToken bob;
    FlashMinter minter;

    function setUp() public {
        EIP1967Proxy bobProxy = new EIP1967Proxy(address(this), mockImpl, "");
        BobToken bobImpl = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(bobImpl));
        bob = BobToken(address(bobProxy));

        minter = new FlashMinter(address(bob), 1000 ether, user1, 0.001 ether, 0.1 ether);

        bob.updateMinter(address(minter), true, true);
        bob.updateMinter(address(this), true, true);

        vm.warp(block.timestamp + 1 days);
    }

    function testGetters() public {
        assertEq(minter.flashFee(address(bob), 50 ether), 0.05 ether);
        assertEq(minter.flashFee(address(bob), 100 ether), 0.1 ether);
        assertEq(minter.flashFee(address(bob), 500 ether), 0.1 ether);
        assertEq(minter.maxFlashLoan(address(bob)), 1000 ether);
    }

    function testFlashLoan() public {
        ERC3156FlashBorrowerMock mock = new ERC3156FlashBorrowerMock(address(bob), false, false);
        vm.expectRevert(bytes("E1"));
        minter.flashLoan(IERC3156FlashBorrower(mock), address(bob), 100 ether, "");

        mock = new ERC3156FlashBorrowerMock(address(minter), false, false);
        vm.expectRevert("FlashMinter: invalid return value");
        minter.flashLoan(IERC3156FlashBorrower(mock), address(bob), 100 ether, "");

        mock = new ERC3156FlashBorrowerMock(address(minter), true, false);
        vm.expectRevert("ERC20: insufficient allowance");
        minter.flashLoan(IERC3156FlashBorrower(mock), address(bob), 100 ether, "");

        mock = new ERC3156FlashBorrowerMock(address(minter), true, true);
        vm.expectRevert("ERC20: amount exceeds balance");
        minter.flashLoan(IERC3156FlashBorrower(mock), address(bob), 100 ether, "");

        mock = new ERC3156FlashBorrowerMock(address(minter), true, true);
        vm.expectRevert("FlashMinter: amount exceeds maxFlashLoan");
        minter.flashLoan(IERC3156FlashBorrower(mock), address(bob), 2000 ether, "");

        mock = new ERC3156FlashBorrowerMock(address(minter), true, true);
        bob.mint(address(mock), minter.flashFee(address(bob), 100 ether));
        minter.flashLoan(IERC3156FlashBorrower(mock), address(bob), 100 ether, "");

        assertEq(bob.totalSupply(), 0.1 ether);
        assertEq(bob.balanceOf(address(minter)), 0);
        assertEq(bob.balanceOf(address(mock)), 0);
        assertEq(bob.balanceOf(address(user1)), 0.1 ether);
    }

    function testUpdateConfig() external {
        ERC3156FlashBorrowerMock mock = new ERC3156FlashBorrowerMock(address(minter), true, true);
        bob.mint(address(mock), minter.flashFee(address(bob), 100 ether));
        minter.flashLoan(IERC3156FlashBorrower(mock), address(bob), 100 ether, "");

        assertEq(bob.totalSupply(), 0.1 ether);
        assertEq(bob.balanceOf(address(minter)), 0);
        assertEq(bob.balanceOf(address(mock)), 0);
        assertEq(bob.balanceOf(address(user1)), 0.1 ether);

        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        minter.updateConfig(10000 ether, user2, 0.01 ether, 1 ether);
        minter.updateConfig(10000 ether, user2, 0.01 ether, 1 ether);

        assertEq(minter.maxFlashLoan(address(bob)), 10000 ether);
        assertEq(minter.flashFee(address(bob), 10 ether), 0.1 ether);
        assertEq(minter.flashFee(address(bob), 100 ether), 1 ether);
        assertEq(minter.flashFee(address(bob), 1000 ether), 1 ether);

        mock = new ERC3156FlashBorrowerMock(address(minter), true, true);
        bob.mint(address(mock), minter.flashFee(address(bob), 2000 ether));
        minter.flashLoan(IERC3156FlashBorrower(mock), address(bob), 2000 ether, "");

        assertEq(bob.totalSupply(), 1.1 ether);
        assertEq(bob.balanceOf(address(minter)), 0);
        assertEq(bob.balanceOf(address(mock)), 0);
        assertEq(bob.balanceOf(address(user1)), 0.1 ether);
        assertEq(bob.balanceOf(address(user2)), 1 ether);
    }
}
