// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";

address constant deployer = 0x39F0bD56c1439a22Ee90b4972c16b7868D161981;
address constant user1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
address constant user2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
address constant user3 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
address constant user4 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

uint256 constant pk1 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

address constant mockImpl = address(0xdead);
address constant bobVanityAddr = address(0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B);
bytes32 constant bobSalt = bytes32(uint256(285834900769));

uint256 constant forkBlockMainnet = 17000000;
string constant forkRpcUrlMainnet =
    "https://rpc.ankr.com/eth/9459a7b0289d1177790c6d0e02b5d2c852d173cfae0ce30ba12b1e7ad3b73cc8";
uint256 constant forkBlockPolygon = 37000000;
string constant forkRpcUrlPolygon =
    "https://rpc.ankr.com/polygon/9459a7b0289d1177790c6d0e02b5d2c852d173cfae0ce30ba12b1e7ad3b73cc8";
uint256 constant forkBlockOptimism = 52000000;
string constant forkRpcUrlOptimism = "https://1rpc.io/op";
