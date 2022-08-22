// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";

address constant deployer = 0xBF3d6f830CE263CAE987193982192Cd990442B53;
address constant user1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
address constant user2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
address constant user3 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

uint256 constant pk1 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

address constant mockImpl = address(0xdead);
address constant bobTokenVanityAddr = address(0xB0B65813DD450B7c98Fed97404fAbAe179A00B0B);
bytes32 constant bobTokenSalt = bytes32(uint256(298396503));

string constant forkRpcUrl = "https://rpc.ankr.com/eth";
