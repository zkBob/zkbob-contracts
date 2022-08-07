// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../src/BobAuction.sol";

contract DeployBobAuction is Script {
    address private constant owner = address(0);
    uint96 private constant feeAmount = 0.25 ether;
    address private constant feeReceiver = address(0);
    address private constant manager = address(0);

    address private constant dutch = address(0);
    address private constant english = address(0);
    address private constant batch = address(0);

    uint256 private constant duration = 3 days;

    function run() external {
        require(dutch == address(0) || Address.isContract(dutch), "Dutch is not a contract");
        require(english == address(0) || Address.isContract(english), "English is not a contract");
        require(batch == address(0) || Address.isContract(batch), "Batch is not a contract");

        vm.startBroadcast();

        BobAuction auction =
            new BobAuction(feeAmount, feeReceiver, manager == address(0) ? tx.origin : manager, dutch, english, batch);

        auction.setDuration(duration);

        if (owner != address(0) && tx.origin != owner) {
            auction.transferOwnership(owner);
        }

        vm.stopBroadcast();

        require(auction.feeAmount() == feeAmount, "Fee is not configured");
        require(auction.feeReceiver() == feeReceiver, "Fee receiver is not configured");
        require(auction.owner() == owner == address(0) ? tx.origin : owner, "Owner is not configured");
        require(address(auction.dutch()) == dutch, "Dutch is not configured");
        require(address(auction.english()) == english, "English is not configured");
        require(address(auction.batch()) == batch, "Batch is not configured");
        require(auction.duration() == duration, "Duration is not configured");
    }
}
