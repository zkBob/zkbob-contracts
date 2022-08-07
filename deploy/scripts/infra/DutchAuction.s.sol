// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "../../../src/auction/DutchAuction.sol";

contract DeployDutchAuction is Script {
    address private constant owner = address(0);
    uint96 private constant feeAmount = 0.01 ether;
    address private constant feeReceiver = address(0);

    function run() external {
        vm.startBroadcast();

        DutchAuction auction = new DutchAuction(feeAmount, feeReceiver);

        if (owner != address(0) && tx.origin != owner) {
            auction.transferOwnership(owner);
        }

        vm.stopBroadcast();

        require(auction.feeAmount() == feeAmount, "Fee is not configured");
        require(auction.feeReceiver() == feeReceiver, "Fee receiver is not configured");
        require(auction.owner() == owner == address(0) ? tx.origin : owner, "Owner is not configured");
    }
}
