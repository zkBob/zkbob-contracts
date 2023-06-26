// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";

enum PoolType {
    BOB,
    ETH,
    USDC,
    ERC20
}

// common
address constant deployer = 0x39F0bD56c1439a22Ee90b4972c16b7868D161981;
address constant admin = 0x14fc6a1a996A2EB889cF86e5c8cD17323bC85290;
address constant owner = 0x14fc6a1a996A2EB889cF86e5c8cD17323bC85290;
address constant mockImpl = address(0xdead);

// bob
address constant bobMinter = 0xd4a3D9Ca00fa1fD8833D560F9217458E61c446d8;
address constant bobVanityAddr = address(0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B);
bytes32 constant bobSalt = bytes32(uint256(285834900769));

// zkbob
uint256 constant zkBobPoolId = 2; // 0 is reserved for Polygon MVP pool, do not use for other deployments
PoolType constant zkBobPoolType = PoolType.ETH;
string constant zkBobVerifiers = "prodV2";
address constant zkBobToken = 0x4200000000000000000000000000000000000006;
uint256 constant zkBobInitialRoot = 11469701942666298368112882412133877458305516134926649826543144744382391691533;
address constant zkBobRelayer = 0x65Eb51b16678d57Bb0bB8d160D1b9D0a57880512;
address constant zkBobRelayerFeeReceiver = 0xa022d235755D25fC2B7335ceCBD08A8658d07333;
string constant zkBobRelayerURL = "https://relayer-eth-mvp.zkbob.com";
uint256 constant zkBobPoolCap = 1_000 ether;
uint256 constant zkBobDailyDepositCap = 150 ether;
uint256 constant zkBobDailyWithdrawalCap = 150 ether;
uint256 constant zkBobDailyUserDepositCap = 5 ether;
uint256 constant zkBobDepositCap = 5 ether;
uint256 constant zkBobDailyUserDirectDepositCap = 5 ether;
uint256 constant zkBobDirectDepositCap = 1 ether;
uint256 constant zkBobDirectDepositFee = 0.0002 gwei; // Based on https://optimistic.etherscan.io/tx/0x320f201bede2bb0c89f04d555a5936192930685bfeee1fe030df0799bfdd57a9
uint256 constant zkBobDirectDepositTimeout = 1 days;
address constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

//KYC
address constant KycNFT = 0xDA0849088D63e1e708a469e11724c1Bd2f22C49D;

// new zkbob impl
address constant zkBobPool = 0x72e6B59D4a90ab232e55D4BB7ed2dD17494D62fB;

// vault
address constant vaultYieldAdmin = 0x0000000000000000000000000000000000000000;
address constant vaultInvestAdmin = 0x0000000000000000000000000000000000000000;
address constant vaultCollateralTokenAddress = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
uint128 constant vaultCollateralPrice = 1_000_000;
uint64 constant vaultCollateralInFee = 0;
uint64 constant vaultCollateralOutFee = 0;
address constant vaultCollateralAAVELendingPool = 0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf;
uint128 constant vaultCollateralBuffer = 1_000_000 * 1_000_000;
uint96 constant vaultCollateralDust = 1_000_000;

// bob seller
address constant uniV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant uniV3Quoter = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
uint24 constant fee0 = 500;
address constant usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
uint24 constant fee1 = 500;
