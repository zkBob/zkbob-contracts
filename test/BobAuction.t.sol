// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "forge-std/Test.sol";
import "./shared/Env.t.sol";
import "./shared/EIP2470.t.sol";
import "../src/proxy/EIP1967Proxy.sol";
import "../src/BobToken.sol";
import "../src/BobAuction.sol";

contract BobAuctionTest is Test, EIP2470Test {
    EIP1967Proxy bobProxy;
    BobToken bob;
    BobAuction auction;
    XPBobToken xpToken;
    ERC20PresetMinterPauser sellToken;

    DutchAuction dutch;
    EnglishAuction english;
    IBatchAuction batch;

    function setUp() public {
        vm.createSelectFork(forkRpcUrlMainnet);

        vm.startPrank(deployer);

        bytes memory creationCode = bytes.concat(type(EIP1967Proxy).creationCode, abi.encode(deployer, mockImpl, ""));
        bobProxy = EIP1967Proxy(factory.deploy(creationCode, bobSalt));
        BobToken impl = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(impl));
        bob = BobToken(address(bobProxy));
        bob.updateMinter(deployer, true, true);

        EIP1967Proxy proxy = new EIP1967Proxy(deployer, address(mockImpl), "");
        xpToken = new XPBobToken(address(proxy));
        proxy.upgradeTo(address(xpToken));
        xpToken = XPBobToken(address(proxy));
        xpToken.updateMinter(deployer, true, true);
        xpToken.mint(user2, 1e6 ether);

        sellToken = new ERC20PresetMinterPauser("Sold Token", "SELL");

        dutch = new DutchAuction(0.01 ether, deployer);
        english = new EnglishAuction(0.01 ether, deployer);
        batch = IBatchAuction(address(0x0b7fFc1f4AD541A4Ed16b40D8c37f0929158D101));

        auction = new BobAuction(
            0.1 ether, deployer, user1, 3 days, address(xpToken), address(dutch), address(english), address(batch)
        );
        vm.stopPrank();

        vm.startPrank(user2);
        xpToken.approve(address(dutch), type(uint256).max);
        xpToken.approve(address(english), type(uint256).max);
        xpToken.approve(address(batch), type(uint256).max);
        vm.stopPrank();
    }

    function testDutchAuction() public {
        vm.startPrank(deployer);
        sellToken.mint(address(auction), 200 ether);
        auction.startDutchAuction(
            address(sellToken), 100 ether, uint96(block.timestamp + 1 hours), 1 minutes, 200 ether, 0.05 ether
        );
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("DutchAuction: not started");
        dutch.buy(0, 10 ether, 200 ether);
        vm.warp(block.timestamp + 1 hours);
        dutch.buy(0, 10 ether, 200 ether);
        vm.warp(block.timestamp + 24 hours);
        dutch.buy(0, 10 ether, 200 ether);
        vm.stopPrank();

        vm.startPrank(deployer);
        vm.expectRevert("DutchAuction: not closed");
        auction.claimDutchAuction(0);
        vm.warp(block.timestamp + 2 days);
        auction.claimDutchAuction(0);
        vm.stopPrank();

        assertEq(xpToken.balanceOf(address(auction)), 0);
        assertEq(sellToken.balanceOf(address(deployer)), 10 ether + 1 ether);
        assertEq(sellToken.balanceOf(address(user2)), 5 ether + 7.8125 ether);
        assertEq(sellToken.balanceOf(address(auction)), 200 ether - 10 ether - 1 ether - 5 ether - 7.8125 ether);
    }

    function testEnglishAuction() public {
        vm.startPrank(deployer);
        sellToken.mint(address(auction), 200 ether);
        auction.startEnglishAuction(
            address(sellToken), 100 ether, uint96(block.timestamp + 1 hours), 1 hours, 10 ether, 1 ether
        );
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("EnglishAuction: not started");
        english.bid(0, 10 ether);
        vm.warp(block.timestamp + 2 hours);
        english.bid(0, 15 ether);
        vm.stopPrank();

        vm.startPrank(deployer);
        vm.expectRevert("EnglishAuction: waiting for tick");
        auction.claimEnglishAuction(0);
        vm.warp(block.timestamp + 2 hours);
        auction.claimEnglishAuction(0);
        vm.stopPrank();

        english.claimForWinner(0);

        assertEq(xpToken.balanceOf(address(auction)), 0);
        assertEq(sellToken.balanceOf(address(deployer)), 10 ether + 1 ether);
        assertEq(sellToken.balanceOf(address(user2)), 100 ether);
        assertEq(sellToken.balanceOf(address(auction)), 200 ether - 10 ether - 1 ether - 100 ether);
    }

    function testBatchAuction() public {
        vm.startPrank(deployer);
        sellToken.mint(address(auction), 200 ether);
        // 100 ether of tokens for at least 10 ether, 1 ether min bid
        uint256 id = auction.startBatchAuction(address(sellToken), 100 ether, 10 ether, 1 ether - 1);
        vm.stopPrank();

        vm.startPrank(user2);
        uint96[] memory minBuyAmounts = new uint96[](1);
        minBuyAmounts[0] = 10 ether;
        uint96[] memory sellAmounts = new uint96[](1);
        sellAmounts[0] = 2 ether;
        bytes32[] memory prevSellOrders = new bytes32[](1);
        prevSellOrders[0] = bytes32(0x0000000000000000000000000000000000000000000000000000000000000001);
        batch.placeSellOrders(id, minBuyAmounts, sellAmounts, prevSellOrders, "");
        vm.stopPrank();

        vm.startPrank(deployer);
        vm.expectRevert("Auction not in solution submission phase");
        auction.claimBatchAuction(id);
        vm.warp(block.timestamp + 4 days);
        auction.claimBatchAuction(id);
        vm.stopPrank();

        bytes32[] memory orders = new bytes32[](1);
        orders[0] = _encodeOrder(user2, 10 ether, 2 ether);
        batch.claimFromParticipantOrder(id, orders);

        assertEq(xpToken.balanceOf(address(auction)), 0);
        assertEq(sellToken.balanceOf(address(deployer)), 10 ether);
        assertEq(sellToken.balanceOf(address(user2)), 20 ether);
        assertEq(sellToken.balanceOf(address(auction)), 200 ether - 10 ether - 10 ether * 2);
    }

    function _encodeOrder(address user, uint96 buyAmount, uint96 sellAmount) internal view returns (bytes32) {
        return bytes32((uint256(batch.getUserId(user)) << 192) + (uint256(buyAmount) << 96) + uint256(sellAmount));
    }
}
