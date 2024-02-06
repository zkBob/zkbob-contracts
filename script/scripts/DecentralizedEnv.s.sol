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

// zkbob
uint256 constant zkBobPoolId = 0xffff09; // 0 is reserved for Polygon MVP pool, do not use for other deployments
PoolType constant zkBobPoolType = PoolType.BOB;
string constant zkBobVerifiers = "stageV2";
address constant zkBobToken = 0x2C74B18e2f84B78ac67428d0c7a9898515f0c46f; 
uint256 constant zkBobInitialRoot = 11469701942666298368112882412133877458305516134926649826543144744382391691533;

address constant zkBobRelayer1 = 0xFec49782FE8e11De9Fb3Ba645a76FE914FFfe3cb; 
address constant zkBobRelayerFeeReceiver1 = 0xFec49782FE8e11De9Fb3Ba645a76FE914FFfe3cb;
address constant zkBobRelayer2 = 0x7D2D146a7AD3F0Dc398AA718a9bFCa2Bc873a5FD; 
address constant zkBobRelayerFeeReceiver2 = 0x7D2D146a7AD3F0Dc398AA718a9bFCa2Bc873a5FD;
string constant zkBobRelayerURL = "";

uint256 constant zkBobPoolCap = 1_000_000 gwei;
uint256 constant zkBobDailyDepositCap = 100_000 gwei;
uint256 constant zkBobDailyWithdrawalCap = 100_000 gwei;
uint256 constant zkBobDailyUserDepositCap = 10_000 gwei;
uint256 constant zkBobDepositCap = 10_000 gwei;
uint256 constant zkBobDailyUserDirectDepositCap = 0;
uint256 constant zkBobDirectDepositCap = 0;
uint256 constant zkBobDirectDepositFee = 0.1 gwei;
uint256 constant zkBobDirectDepositTimeout = 1 days;
address constant permit2 = address(0);
uint64 constant gracePeriod = 3 minutes;
uint64 constant minTreeUpdateFee = 0.1 gwei;
