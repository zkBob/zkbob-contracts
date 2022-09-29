// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";

// common
address constant deployer = 0x39F0bD56c1439a22Ee90b4972c16b7868D161981;
address constant admin = 0xd4a3D9Ca00fa1fD8833D560F9217458E61c446d8;
address constant owner = 0xd4a3D9Ca00fa1fD8833D560F9217458E61c446d8;
address constant mockImpl = address(0xdead);

// bob
address constant bobMinter = 0xd4a3D9Ca00fa1fD8833D560F9217458E61c446d8;
address constant bobVanityAddr = address(0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B);
bytes32 constant bobSalt = bytes32(uint256(285834900769));

// zkbob
string constant zkBobVerifiers = "prodV1";
uint256 constant zkBobInitialRoot = 11469701942666298368112882412133877458305516134926649826543144744382391691533;
address constant zkBobRelayer = 0xc2c4AD59B78F4A0aFD0CDB8133E640Db08Fa5b90;
address constant zkBobRelayerFeeReceiver = 0x758768EC473279c4B1Aa61FA5450745340D4B17d;
string constant zkBobRelayerURL = "https://relayer-mvp.zkbob.com";
uint256 constant zkBobPoolCap = 1_000_000 ether;
uint256 constant zkBobDailyDepositCap = 100_000 ether;
uint256 constant zkBobDailyWithdrawalCap = 100_000 ether;
uint256 constant zkBobDailyUserDepositCap = 10_000 ether;
uint256 constant zkBobDepositCap = 10_000 ether;

// bob seller
address constant uniV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
uint24 constant fee0 = 500;
address constant usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
uint24 constant fee1 = 500;
