// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../src/BobAuction.sol";

contract DeployBobAuction is Script {
    function run() external {
        require(dutchAuction == address(0) || Address.isContract(dutchAuction), "Dutch is not a contract");
        require(englishAuction == address(0) || Address.isContract(englishAuction), "English is not a contract");
        require(batchAuction == address(0) || Address.isContract(batchAuction), "Batch is not a contract");

        vm.startBroadcast();

        BobAuction auction = new BobAuction(
            bobAuctionFeeAmount, bobAuctionFeeReceiver, bobAuctionManager, bobAuctionDuration,
            xpToken, dutchAuction, englishAuction, batchAuction
        );

        if (owner != address(0)) {
            auction.transferOwnership(owner);
        }

        vm.stopBroadcast();

        require(auction.feeAmount() == bobAuctionFeeAmount, "Fee is not configured");
        require(auction.feeReceiver() == bobAuctionFeeReceiver, "Fee receiver is not configured");
        require(auction.manager() == bobAuctionManager, "Manager is not configured");
        require(auction.duration() == bobAuctionDuration, "Duration is not configured");
        require(auction.owner() == owner, "Owner is not configured");
        require(address(auction.dutch()) == dutchAuction, "Dutch auction is not configured");
        require(address(auction.english()) == englishAuction, "English auction is not configured");
        require(address(auction.batch()) == batchAuction, "Batch auction is not configured");
    }
}
