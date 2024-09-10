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
address constant deployer = 0x37493bFe9c8c31fAbe8615C988e83D59D1a667a9;
address constant admin = 0x37493bFe9c8c31fAbe8615C988e83D59D1a667a9;
address constant owner = 0x37493bFe9c8c31fAbe8615C988e83D59D1a667a9;
address constant mockImpl = address(0xdead);

// bob
address constant bobMinter = 0xd4a3D9Ca00fa1fD8833D560F9217458E61c446d8;
address constant bobVanityAddr = address(0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B);
bytes32 constant bobSalt = bytes32(uint256(285834900769));

// zkbob
uint256 constant zkBobPoolId = 0xffff0a; // 0 is reserved for Polygon MVP pool, do not use for other deployments
PoolType constant zkBobPoolType = PoolType.BOB;
string constant zkBobVerifiers = "stageV2";
address constant zkBobToken = 0x2C74B18e2f84B78ac67428d0c7a9898515f0c46f;
uint256 constant zkBobInitialRoot = 11469701942666298368112882412133877458305516134926649826543144744382391691533;
address constant zkBobProxy = 0xFec49782FE8e11De9Fb3Ba645a76FE914FFfe3cb;
address constant zkBobProxyFeeReceiver = 0xFec49782FE8e11De9Fb3Ba645a76FE914FFfe3cb;
address constant zkBobProver = 0x7D2D146a7AD3F0Dc398AA718a9bFCa2Bc873a5FD;
address constant zkBobProverFeeReceiver = 0x7D2D146a7AD3F0Dc398AA718a9bFCa2Bc873a5FD;
uint256 constant zkBobDirectDepositFee = 0.1 gwei;
uint256 constant zkBobDirectDepositTimeout = 1 days;
address constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

// decentralized
uint64 constant gracePeriod = 3 minutes; // TODO
uint64 constant minTreeUpdateFee = 0.1 gwei;
bool constant allowListEnabled = true;

// accounting
address constant kycManager = address(0);

uint256 constant tier0TvlCap = 2_000_000 gwei;
uint256 constant tier0DailyDepositCap = 300_000 gwei;
uint256 constant tier0DailyWithdrawalCap = 300_000 gwei;
uint256 constant tier0DailyUserDepositCap = 10_000 gwei;
uint256 constant tier0DepositCap = 10_000 gwei;
uint256 constant tier0DailyUserDirectDepositCap = 10_000 gwei;
uint256 constant tier0DirectDepositCap = 1_000 gwei;

uint256 constant tier1TvlCap = 2_000_000 gwei;
uint256 constant tier1DailyDepositCap = 300_000 gwei;
uint256 constant tier1DailyWithdrawalCap = 300_000 gwei;
uint256 constant tier1DailyUserDepositCap = 100_000 gwei;
uint256 constant tier1DepositCap = 100_000 gwei;
uint256 constant tier1DailyUserDirectDepositCap = 10_000 gwei;
uint256 constant tier1DirectDepositCap = 1_000 gwei;

uint256 constant tier254TvlCap = 2_000_000 gwei;
uint256 constant tier254DailyDepositCap = 300_000 gwei;
uint256 constant tier254DailyWithdrawalCap = 300_000 gwei;
uint256 constant tier254DailyUserDepositCap = 20_000 gwei;
uint256 constant tier254DepositCap = 20_000 gwei;
uint256 constant tier254DailyUserDirectDepositCap = 10_000 gwei;
uint256 constant tier254DirectDepositCap = 1_000 gwei;

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
