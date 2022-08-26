// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";

// common
address constant deployer = 0xBF3d6f830CE263CAE987193982192Cd990442B53;
address constant admin = 0xBF3d6f830CE263CAE987193982192Cd990442B53;
address constant owner = 0xBF3d6f830CE263CAE987193982192Cd990442B53;
address constant mockImpl = address(0xdead);

// bob
address constant bobMinter = 0xBF3d6f830CE263CAE987193982192Cd990442B53;
address constant bobVanityAddr = address(0xB0bF0014062a51a8a8431F52CBEe0B436E0C9b0b);
bytes32 constant bobSalt = bytes32(uint256(47274243));

// zkbob
string constant zkBobVerifiers = "stageV1";
uint256 constant zkBobInitialRoot = 11469701942666298368112882412133877458305516134926649826543144744382391691533;
address constant zkBobRelayer = 0xBA6f711e1D4dB0CBfbC09D1d11C5Fb7445160673;
address constant zkBobRelayerFeeReceiver = 0xBA6f711e1D4dB0CBfbC09D1d11C5Fb7445160673;
string constant zkBobRelayerURL = "https://relayer.thgkjlr.website";
uint256 constant zkBobPoolCap = 1_000_000 ether;
uint256 constant zkBobDailyDepositCap = 100_000 ether;
uint256 constant zkBobDailyWithdrawalCap = 100_000 ether;
uint256 constant zkBobDailyUserDepositCap = 10_000 ether;
uint256 constant zkBobDepositCap = 10_000 ether;

// xp
address constant xpMinter = 0x0000000000000000000000000000000000000000;

// vault
address constant vaultYieldAdmin = 0x0000000000000000000000000000000000000000;
address constant vaultInvestAdmin = 0x0000000000000000000000000000000000000000;

// auction
address constant auctionOwner = 0x0000000000000000000000000000000000000000;
uint96 constant auctionFeeAmount = 0.01 ether;
address constant auctionFeeReceiver = 0x0000000000000000000000000000000000000000;

// bob auction
address constant xpToken = 0x0000000000000000000000000000000000000000;
uint96 constant bobAuctionFeeAmount = 0.25 ether;
address constant bobAuctionFeeReceiver = 0x0000000000000000000000000000000000000000;
address constant bobAuctionManager = 0x0000000000000000000000000000000000000000;
uint96 constant bobAuctionDuration = 3 days;
address constant dutchAuction = 0x0000000000000000000000000000000000000000;
address constant englishAuction = 0x0000000000000000000000000000000000000000;
address constant batchAuction = 0x0000000000000000000000000000000000000000;
