// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../../src/MultiMinter.sol";

contract DeployMultiMinter is Script {
    address private constant token = address(0);
    address private constant owner = address(0);
    address private constant minter1 = address(0);
    address private constant minter2 = address(0);

    function run() external {
        require(Address.isContract(token), "Token not a contract");

        vm.startBroadcast();

        MultiMinter minter = new MultiMinter(token);

        if (minter1 != address(0)) {
            minter.setMinter(minter1, true);
            require(minter.minter(minter1), "Minter is not configured");
        }

        if (minter2 != address(0)) {
            minter.setMinter(minter2, true);
            require(minter.minter(minter2), "Minter is not configured");
        }

        if (owner != address(0) && tx.origin != owner) {
            minter.transferOwnership(owner);
        }

        vm.stopBroadcast();

        require(minter.owner() == (owner == address(0) ? tx.origin : owner), "Owner is not configured");
    }
}
