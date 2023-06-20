// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../Env.s.sol";

contract DeployTimelockController is Script {
    function run() external {
        vm.startBroadcast();

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = admin;
        executors[0] = deployer;
        TimelockController timelock = new TimelockController(1 days, proposers, executors, address(0));

        vm.stopBroadcast();
    }
}
