// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "forge-std/Test.sol";
import "../shared/Env.t.sol";
import "../../src/auction/DutchAuction.sol";

contract DutchAuctionTest is Test {
    ERC20PresetMinterPauser bidToken;
    ERC20PresetMinterPauser sellToken;
    DutchAuction auction;

    function setUp() public {
        bidToken = new ERC20PresetMinterPauser("Bid Token", "BID");
        sellToken = new ERC20PresetMinterPauser("Sold Token", "SELL");
        sellToken.mint(user1, 1e6 ether);
        bidToken.mint(user2, 1e6 ether);

        auction = new DutchAuction(0.01 ether, deployer);

        vm.prank(user1);
        sellToken.approve(address(auction), 1e6 ether);

        vm.prank(user2);
        bidToken.approve(address(auction), 1e6 ether);
    }

    function testSimpleDutchAuction() public {
        vm.prank(user1);
        auction.start(
            DutchAuction.AuctionData({
                sellToken: address(sellToken),
                bidToken: address(bidToken),
                startTime: 0,
                finalTime: 10 days,
                fundsReceiver: user1,
                auctioneer: user1,
                total: 100 ether,
                startBid: 200 ether,
                finalBid: 10 ether,
                tickTime: 1 hours,
                tickBid: 1 ether,
                status: DutchAuction.Status.New,
                totalSold: 0,
                totalBid: 0,
                allowList: IAllowList(address(0))
            })
        );

        assertEq(sellToken.balanceOf(deployer), 1 ether);

        uint256 bought = 0;
        vm.startPrank(user2);

        auction.buy(0, 1 ether, 200 ether);
        bought += uint256(1 ether) * 100 ether / 200 ether;
        assertEq(sellToken.balanceOf(user2), bought);

        vm.warp(block.timestamp + 4 hours);
        vm.expectRevert("DutchAuction: submitted too early");
        auction.buy(0, 1 ether, 195 ether);

        vm.warp(block.timestamp + 1 hours);
        auction.buy(0, 1 ether, 195 ether);
        bought += uint256(1 ether) * 100 ether / 195 ether;
        assertEq(sellToken.balanceOf(user2), bought);

        vm.warp(block.timestamp + 5 hours);
        auction.buy(0, 1 ether, 195 ether);
        bought += uint256(1 ether) * 100 ether / 190 ether;
        assertEq(sellToken.balanceOf(user2), bought);

        vm.warp(block.timestamp + 190 hours);
        auction.buy(0, 100 ether, 10 ether);
        bought = 100 ether;
        assertEq(sellToken.balanceOf(user2), bought);
        vm.stopPrank();

        vm.prank(user1);
        auction.claim(0);

        assertGt(bidToken.balanceOf(user1), 10 ether);
    }
}
