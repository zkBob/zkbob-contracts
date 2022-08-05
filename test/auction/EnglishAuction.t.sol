// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "forge-std/Test.sol";
import "../../src/auction/EnglishAuction.sol";

contract EnglishAuctionTest is Test {
    ERC20PresetMinterPauser bidToken;
    ERC20PresetMinterPauser sellToken;
    EnglishAuction auction;

    address deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address user1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address user2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address user3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    function setUp() public {
        bidToken = new ERC20PresetMinterPauser("Bid Token", "BID");
        sellToken = new ERC20PresetMinterPauser("Sold Token", "SELL");
        sellToken.mint(user1, 1e6 ether);
        bidToken.mint(user2, 1e6 ether);
        bidToken.mint(user3, 1e6 ether);

        auction = new EnglishAuction(0.01 ether, deployer);

        vm.prank(user1);
        sellToken.approve(address(auction), 1e6 ether);

        vm.prank(user2);
        bidToken.approve(address(auction), 1e6 ether);

        vm.prank(user3);
        bidToken.approve(address(auction), 1e6 ether);
    }

    function testSimpleEnglishAuction() public {
        vm.prank(user1);
        auction.start(
            EnglishAuction.AuctionData({
                sellToken: address(sellToken),
                bidToken: address(bidToken),
                startTime: 0,
                finalTime: 10 days,
                fundsReceiver: user1,
                auctioneer: user1,
                total: 100 ether,
                startBid: 1 ether,
                tickTime: 1 hours,
                tickBid: 1 ether,
                status: EnglishAuction.Status.New,
                currentBid: 0,
                currentBidder: address(0),
                lastBidTime: 0,
                allowList: IAllowList(address(0))
            })
        );

        assertEq(sellToken.balanceOf(deployer), 1 ether);

        vm.prank(user2);
        auction.bid(0, 1 ether);

        vm.prank(user3);
        auction.bid(0, 3 ether);

        vm.prank(user2);
        vm.expectRevert("EnglishAuction: bid too small");
        auction.bid(0, 3.5 ether);

        vm.prank(user2);
        auction.bid(0, 5 ether);

        vm.prank(user2);
        vm.expectRevert("EnglishAuction: already top bidder");
        auction.bid(0, 10 ether);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(user3);
        vm.expectRevert("EnglishAuction: tick passed");
        auction.bid(0, 20 ether);

        auction.claimForWinner(0);

        vm.prank(user1);
        auction.claim(0);

        assertEq(bidToken.balanceOf(user1), 5 ether);
        assertEq(bidToken.balanceOf(user2), 1e6 ether - 5 ether);
        assertEq(bidToken.balanceOf(user3), 1e6 ether);
        assertEq(sellToken.balanceOf(user2), 100 ether);
    }
}
