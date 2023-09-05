// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../../shared/Env.t.sol";
import "../../../src/zkbob/manager/kyc/SimpleKYCProviderManager.sol";
import "../../../src/zkbob/utils/ZkBobAccounting.sol";
import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract ZkBobAccountingTest is Test {
    ZkBobAccounting pool;

    uint8 internal constant TIER_FOR_KYC = 254;

    function setUp() public {
        pool = new ZkBobAccounting(address(this), 1_000_000_000);

        pool.setLimits(0, 1000 gwei, 1000 gwei, 1000 gwei, 1000 gwei, 1000 gwei, 0, 0);

        vm.warp(1000 weeks);
    }

    function _checkStats(uint256 _maxWeeklyAvgTvl, uint256 _maxWeeklyTxCount, uint256 _txCount) internal {
        (uint256 maxWeeklyAvgTvl, uint256 maxWeeklyTxCount,,,, uint256 txCount) = pool.slot0();
        assertEq(maxWeeklyAvgTvl, _maxWeeklyAvgTvl);
        assertEq(maxWeeklyTxCount, _maxWeeklyTxCount);
        assertEq(txCount, _txCount);
    }

    function testBasicStats() public {
        // baseline (100 BOB tvl ~13.8 days)
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, int256(100 gwei));
        vm.warp(block.timestamp + 20 minutes);
        for (uint256 i = 1; i < 999; i++) {
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 0);
            vm.warp(block.timestamp + 20 minutes);
        }
        _checkStats({_maxWeeklyAvgTvl: 100, _maxWeeklyTxCount: 504, _txCount: 999});

        // 100 -> 300 BOB tvl change for ~2.8 days
        for (uint256 i = 0; i < 201; i++) {
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 1 gwei);
            vm.warp(block.timestamp + 20 minutes);
        }
        _checkStats({_maxWeeklyAvgTvl: 138, _maxWeeklyTxCount: 504, _txCount: 1200});

        // 300 BOB tvl for ~1.4 days
        for (uint256 i = 0; i < 204; i++) {
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 0);
            vm.warp(block.timestamp + 10 minutes);
        }
        _checkStats({_maxWeeklyAvgTvl: 199, _maxWeeklyTxCount: 603, _txCount: 1404});

        // back to 100 BOB tvl
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, int256(-200 gwei));
        vm.warp(block.timestamp + 30 minutes);
        for (uint256 i = 1; i < 1000; i++) {
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 0);
            vm.warp(block.timestamp + 30 minutes);
        }
        _checkStats({_maxWeeklyAvgTvl: 215, _maxWeeklyTxCount: 606, _txCount: 2404});
    }

    function testSparseIntervals() public {
        // baseline (100 BOB tvl ~13.8 days)
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, int256(100 gwei));
        vm.warp(block.timestamp + 20 minutes);
        for (uint256 i = 1; i < 999; i++) {
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 0);
            vm.warp(block.timestamp + 20 minutes);
        }
        for (uint256 i = 1; i <= 10; i++) {
            for (uint256 j = 0; j < 10; j++) {
                pool.recordOperation(
                    IZkBobAccounting.TxType.Common, user1, i == 1 && j == 0 ? int256(100 gwei) : int256(0)
                );
            }
            vm.warp(block.timestamp + i * 1 hours);
        }
        for (uint256 i = 0; i < 1000; i++) {
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, i == 0 ? int256(-100 gwei) : int256(0));
            vm.warp(block.timestamp + 30 minutes);
        }
        _checkStats({_maxWeeklyAvgTvl: 130, _maxWeeklyTxCount: 523, _txCount: 2099});
    }

    function testLaggingBehind() public {
        // baseline (100 BOB tvl ~13.8 days)
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, int256(100 gwei));
        vm.warp(block.timestamp + 20 minutes);
        for (uint256 i = 1; i < 999; i++) {
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 0);
            vm.warp(block.timestamp + 20 minutes);
        }

        // 200 BOB tvl for 10 days
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, int256(100 gwei));
        vm.warp(block.timestamp + 6 hours);
        for (uint256 i = 1; i < 40; i++) {
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 0);
            vm.warp(block.timestamp + 6 hours);
        }
        // since tail pointer didn't catch up, max tvl is still less than 200 BOB
        _checkStats({_maxWeeklyAvgTvl: 108, _maxWeeklyTxCount: 504, _txCount: 1039});

        // 200 BOB tvl for 7 days
        for (uint256 i = 0; i < 168; i++) {
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 0);
            vm.warp(block.timestamp + 1 hours);
        }
        // since tail pointer didn't catch up, max tvl is still less than 200 BOB
        _checkStats({_maxWeeklyAvgTvl: 200, _maxWeeklyTxCount: 504, _txCount: 1207});
    }

    function testDepositCap() public {
        pool.setLimits(0, 1000 gwei, 500 gwei, 500 gwei, 300 gwei, 100 gwei, 0, 0);

        vm.expectRevert("ZkBobAccounting: single deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 200 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 100 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 50 gwei);
    }

    function testDailyUserDepositCap() public {
        pool.setLimits(0, 1000 gwei, 500 gwei, 500 gwei, 200 gwei, 100 gwei, 0, 0);

        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 100 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 100 gwei);
        vm.expectRevert("ZkBobAccounting: daily user deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 100 gwei);
    }

    function testDailyDepositCap() public {
        pool.setLimits(0, 1000 gwei, 500 gwei, 500 gwei, 200 gwei, 100 gwei, 0, 0);

        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 100 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 100 gwei);

        pool.recordOperation(IZkBobAccounting.TxType.Common, user2, 100 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.Common, user2, 100 gwei);

        pool.recordOperation(IZkBobAccounting.TxType.Common, user3, 100 gwei);
        vm.expectRevert("ZkBobAccounting: daily deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user3, 100 gwei);
    }

    function testTvlCap() public {
        pool.setLimits(0, 1000 gwei, 500 gwei, 500 gwei, 200 gwei, 100 gwei, 0, 0);

        for (uint256 i = 0; i < 10; i++) {
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 100 gwei);
            vm.warp(block.timestamp + 1 days);
        }

        vm.expectRevert("ZkBobAccounting: tvl cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 100 gwei);
    }

    function testDirectDepositCap() public {
        pool.setLimits(0, 1000 gwei, 500 gwei, 500 gwei, 200 gwei, 100 gwei, 10 gwei, 2 gwei);

        pool.recordOperation(IZkBobAccounting.TxType.DirectDeposit, user1, 1 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.DirectDeposit, user1, 2 gwei);
        vm.expectRevert("ZkBobAccounting: single direct deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.DirectDeposit, user1, 5 gwei);
        vm.expectRevert("ZkBobAccounting: single direct deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.DirectDeposit, user1, 50 gwei);
    }

    function testDailyUserDirectDepositCap() public {
        pool.setLimits(0, 1000 gwei, 500 gwei, 500 gwei, 200 gwei, 100 gwei, 10 gwei, 5 gwei);

        pool.recordOperation(IZkBobAccounting.TxType.DirectDeposit, user1, 4 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.DirectDeposit, user1, 4 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.DirectDeposit, user2, 4 gwei);

        vm.expectRevert("ZkBobAccounting: daily user direct deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.DirectDeposit, user1, 4 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.DirectDeposit, user2, 4 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.DirectDeposit, user1, 2 gwei);
    }

    function testDailyUserDepositCapReset() public {
        pool.setLimits(0, 10000 gwei, 500 gwei, 500 gwei, 200 gwei, 100 gwei, 0, 0);

        for (uint256 i = 0; i < 5; i++) {
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 100 gwei);
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 100 gwei);
            vm.expectRevert("ZkBobAccounting: daily user deposit cap exceeded");
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 100 gwei);

            vm.warp(block.timestamp + 1 days);
        }
    }

    function testDailyDepositCapReset() public {
        pool.setLimits(0, 10000 gwei, 500 gwei, 500 gwei, 300 gwei, 150 gwei, 0, 0);

        for (uint256 i = 0; i < 5; i++) {
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 150 gwei);
            pool.recordOperation(IZkBobAccounting.TxType.Common, user2, 150 gwei);
            pool.recordOperation(IZkBobAccounting.TxType.Common, user3, 150 gwei);

            vm.expectRevert("ZkBobAccounting: daily deposit cap exceeded");
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 150 gwei);
            vm.expectRevert("ZkBobAccounting: daily deposit cap exceeded");
            pool.recordOperation(IZkBobAccounting.TxType.Common, user2, 150 gwei);
            vm.expectRevert("ZkBobAccounting: daily deposit cap exceeded");
            pool.recordOperation(IZkBobAccounting.TxType.Common, user3, 150 gwei);

            vm.warp(block.timestamp + 1 days);
        }
    }

    function testDailyWithdrawalCap() public {
        pool.setLimits(0, 1000 gwei, 500 gwei, 300 gwei, 200 gwei, 100 gwei, 0, 0);

        for (uint256 i = 0; i < 10; i++) {
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 100 gwei);
            vm.warp(block.timestamp + 1 days);
        }

        pool.recordOperation(IZkBobAccounting.TxType.Common, user2, -100 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.Common, user2, -100 gwei);

        pool.recordOperation(IZkBobAccounting.TxType.Common, user3, -100 gwei);
        vm.expectRevert("ZkBobAccounting: daily withdrawal cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user3, -100 gwei);
    }

    function testDailyWithdrawalCapReset() public {
        pool.setLimits(0, 10000 gwei, 500 gwei, 500 gwei, 300 gwei, 100 gwei, 0, 0);

        for (uint256 i = 0; i < 100; i++) {
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 100 gwei);
            vm.warp(block.timestamp + 1 days);
        }

        for (uint256 i = 0; i < 5; i++) {
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, -150 gwei);
            pool.recordOperation(IZkBobAccounting.TxType.Common, user2, -150 gwei);
            pool.recordOperation(IZkBobAccounting.TxType.Common, user3, -150 gwei);

            vm.expectRevert("ZkBobAccounting: daily withdrawal cap exceeded");
            pool.recordOperation(IZkBobAccounting.TxType.Common, user1, -150 gwei);
            vm.expectRevert("ZkBobAccounting: daily withdrawal cap exceeded");
            pool.recordOperation(IZkBobAccounting.TxType.Common, user2, -150 gwei);
            vm.expectRevert("ZkBobAccounting: daily withdrawal cap exceeded");
            pool.recordOperation(IZkBobAccounting.TxType.Common, user3, -150 gwei);

            vm.warp(block.timestamp + 1 days);
        }
    }

    function testDailyUserDirectDepositCapReset() public {
        pool.setLimits(0, 1000 gwei, 500 gwei, 500 gwei, 200 gwei, 100 gwei, 10 gwei, 5 gwei);

        for (uint256 i = 0; i < 5; i++) {
            pool.recordOperation(IZkBobAccounting.TxType.DirectDeposit, user1, 4 gwei);
            pool.recordOperation(IZkBobAccounting.TxType.DirectDeposit, user1, 4 gwei);
            vm.expectRevert("ZkBobAccounting: daily user direct deposit cap exceeded");
            pool.recordOperation(IZkBobAccounting.TxType.DirectDeposit, user1, 4 gwei);

            vm.warp(block.timestamp + 1 days);
        }
    }

    function testGetLimitsFor() public {
        pool.setLimits(0, 10000 gwei, 500 gwei, 400 gwei, 300 gwei, 150 gwei, 0, 0);

        ZkBobAccounting.Limits memory limits1;
        ZkBobAccounting.Limits memory limits2;

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 10000 gwei);
        assertEq(limits1.tvl, 0 gwei);
        assertEq(limits1.dailyDepositCap, 500 gwei);
        assertEq(limits1.dailyDepositCapUsage, 0 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits1.dailyUserDepositCap, 300 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 0 gwei);
        assertEq(limits1.depositCap, 150 gwei);

        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 50 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 70 gwei);

        pool.recordOperation(IZkBobAccounting.TxType.Common, user2, 100 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.Common, user2, -10 gwei);

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 10000 gwei);
        assertEq(limits1.tvl, 210 gwei);
        assertEq(limits1.dailyDepositCap, 500 gwei);
        assertEq(limits1.dailyDepositCapUsage, 220 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 10 gwei);
        assertEq(limits1.dailyUserDepositCap, 300 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 120 gwei);
        assertEq(limits1.depositCap, 150 gwei);

        limits2 = pool.getLimitsFor(user2);
        assertEq(limits2.tvlCap, 10000 gwei);
        assertEq(limits2.tvl, 210 gwei);
        assertEq(limits2.dailyDepositCap, 500 gwei);
        assertEq(limits2.dailyDepositCapUsage, 220 gwei);
        assertEq(limits2.dailyWithdrawalCap, 400 gwei);
        assertEq(limits2.dailyWithdrawalCapUsage, 10 gwei);
        assertEq(limits2.dailyUserDepositCap, 300 gwei);
        assertEq(limits2.dailyUserDepositCapUsage, 100 gwei);
        assertEq(limits2.depositCap, 150 gwei);

        vm.warp(block.timestamp + 1 days);

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 10000 gwei);
        assertEq(limits1.tvl, 210 gwei);
        assertEq(limits1.dailyDepositCap, 500 gwei);
        assertEq(limits1.dailyDepositCapUsage, 0 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits1.dailyUserDepositCap, 300 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 0 gwei);
        assertEq(limits1.depositCap, 150 gwei);

        limits2 = pool.getLimitsFor(user2);
        assertEq(limits2.tvlCap, 10000 gwei);
        assertEq(limits2.tvl, 210 gwei);
        assertEq(limits2.dailyDepositCap, 500 gwei);
        assertEq(limits2.dailyDepositCapUsage, 0 gwei);
        assertEq(limits2.dailyWithdrawalCap, 400 gwei);
        assertEq(limits2.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits2.dailyUserDepositCap, 300 gwei);
        assertEq(limits2.dailyUserDepositCapUsage, 0 gwei);
        assertEq(limits2.depositCap, 150 gwei);
    }

    function testPoolDailyLimitsReset() public {
        pool.setLimits(0, 10000 gwei, 500 gwei, 400 gwei, 300 gwei, 150 gwei, 0, 0);

        ZkBobAccounting.Limits memory limits1;

        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 70 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, -50 gwei);

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 10000 gwei);
        assertEq(limits1.tvl, 20 gwei);
        assertEq(limits1.dailyDepositCap, 500 gwei);
        assertEq(limits1.dailyDepositCapUsage, 70 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 50 gwei);
        assertEq(limits1.dailyUserDepositCap, 300 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 70 gwei);
        assertEq(limits1.depositCap, 150 gwei);

        vm.warp(block.timestamp + 1 days);

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 10000 gwei);
        assertEq(limits1.tvl, 20 gwei);
        assertEq(limits1.dailyDepositCap, 500 gwei);
        assertEq(limits1.dailyDepositCapUsage, 0 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits1.dailyUserDepositCap, 300 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 0 gwei);
        assertEq(limits1.depositCap, 150 gwei);

        uint256 sid1 = vm.snapshot();
        uint256 sid2 = vm.snapshot();

        // deposit on a new day should reset daily deposit and withdrawal limits
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 100 gwei);

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 10000 gwei);
        assertEq(limits1.tvl, 120 gwei);
        assertEq(limits1.dailyDepositCap, 500 gwei);
        assertEq(limits1.dailyDepositCapUsage, 100 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits1.dailyUserDepositCap, 300 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 100 gwei);
        assertEq(limits1.depositCap, 150 gwei);

        vm.revertTo(sid2);

        // withdrawal on a new day should reset daily deposit and withdrawal limits
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, -10 gwei);

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 10000 gwei);
        assertEq(limits1.tvl, 10 gwei);
        assertEq(limits1.dailyDepositCap, 500 gwei);
        assertEq(limits1.dailyDepositCapUsage, 0 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 10 gwei);
        assertEq(limits1.dailyUserDepositCap, 300 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 0 gwei);
        assertEq(limits1.depositCap, 150 gwei);

        vm.revertTo(sid1);

        // private transfer on a new day should reset daily deposit and withdrawal limits
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 0 gwei);

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 10000 gwei);
        assertEq(limits1.tvl, 20 gwei);
        assertEq(limits1.dailyDepositCap, 500 gwei);
        assertEq(limits1.dailyDepositCapUsage, 0 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits1.dailyUserDepositCap, 300 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 0 gwei);
        assertEq(limits1.depositCap, 150 gwei);
    }

    function testPoolLimitsTiers() public {
        pool.setLimits(0, 600 gwei, 200 gwei, 400 gwei, 180 gwei, 150 gwei, 0, 0);
        pool.setLimits(1, 10000 gwei, 1000 gwei, 800 gwei, 600 gwei, 300 gwei, 0, 0);

        pool.setUserTier(1, user2);
        vm.expectRevert("ZkBobAccounting: non-existing pool limits tier");
        pool.setUserTier(2, user3);
        pool.setUserTier(255, user3);

        // TVL == 0, Tier 0 (0/200, 0/400), Tier 1 (0/1000, 0/800), User 1 (0/180), User2 (0/600)

        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 100 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.Common, user2, 100 gwei);
        vm.expectRevert("ZkBobAccounting: single deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user3, 100 gwei);

        // TVL == 200, Tier 0 (100/200, 0/400), Tier 1 (100/1000, 0/800), User 1 (100/180), User2 (100/600)

        vm.expectRevert("ZkBobAccounting: single deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 200 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.Common, user2, 200 gwei);

        // TVL == 400, Tier 0 (100/200, 0/400), Tier 1 (300/1000, 0/800), User 1 (100/180), User2 (300/600)

        vm.expectRevert("ZkBobAccounting: daily user deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 150 gwei);
        vm.expectRevert("ZkBobAccounting: daily user deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 90 gwei);
        vm.expectRevert("ZkBobAccounting: daily deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user4, 150 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.Common, user2, 150 gwei);

        // TVL == 550, Tier 0 (100/200, 0/400), Tier 1 (450/1000, 0/800), User 1 (100/180), User2 (450/600)

        vm.expectRevert("ZkBobAccounting: tvl cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user1, 150 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.Common, user2, 150 gwei);

        // TVL == 700, Tier 0 (100/200, 0/400), Tier 1 (600/1000, 0/800), User 1 (100/180), User2 (600/600)

        ZkBobAccounting.Limits memory limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 600 gwei);
        assertEq(limits1.tvl, 700 gwei);
        assertEq(limits1.dailyDepositCap, 200 gwei);
        assertEq(limits1.dailyDepositCapUsage, 100 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits1.dailyUserDepositCap, 180 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 100 gwei);
        assertEq(limits1.depositCap, 150 gwei);
        assertEq(limits1.tier, 0);

        ZkBobAccounting.Limits memory limits2 = pool.getLimitsFor(user2);
        assertEq(limits2.tvlCap, 10000 gwei);
        assertEq(limits2.tvl, 700 gwei);
        assertEq(limits2.dailyDepositCap, 1000 gwei);
        assertEq(limits2.dailyDepositCapUsage, 600 gwei);
        assertEq(limits2.dailyWithdrawalCap, 800 gwei);
        assertEq(limits2.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits2.dailyUserDepositCap, 600 gwei);
        assertEq(limits2.dailyUserDepositCapUsage, 600 gwei);
        assertEq(limits2.depositCap, 300 gwei);
        assertEq(limits2.tier, 1);

        ZkBobAccounting.Limits memory limits3 = pool.getLimitsFor(user3);
        assertEq(limits3.tvlCap, 0 gwei);
        assertEq(limits3.tvl, 700 gwei);
        assertEq(limits3.dailyDepositCap, 0 gwei);
        assertEq(limits3.dailyDepositCapUsage, 0 gwei);
        assertEq(limits3.dailyWithdrawalCap, 0 gwei);
        assertEq(limits3.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits3.dailyUserDepositCap, 0 gwei);
        assertEq(limits3.dailyUserDepositCapUsage, 0 gwei);
        assertEq(limits3.depositCap, 0 gwei);
        assertEq(limits3.tier, 255);
    }

    function _setKYCPorviderManager() internal returns (SimpleKYCProviderManager) {
        ERC721PresetMinterPauserAutoId nft = new ERC721PresetMinterPauserAutoId("Test NFT", "tNFT", "http://nft.url/");

        SimpleKYCProviderManager manager = new SimpleKYCProviderManager(nft, TIER_FOR_KYC);
        pool.setKycProvidersManager(manager);

        return manager;
    }

    function _mintNFT(ERC721PresetMinterPauserAutoId _nft, address _user) internal returns (uint256) {
        uint256 tokenId = 0;
        vm.recordLogs();
        _nft.mint(_user);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("Transfer(address,address,uint256)")) {
                tokenId = uint256(entries[i].topics[3]);
                emit log_uint(tokenId);
                break;
            }
            // fail test if the event is not found
            assertLt(i, entries.length - 1);
        }
        return tokenId;
    }

    function testSetKycProvidersManager() public {
        address manager = address(_setKYCPorviderManager());
        assertEq(address(pool.kycProvidersManager()), manager);

        vm.expectRevert("KycProvidersManagerStorage: not a contract");
        pool.setKycProvidersManager(SimpleKYCProviderManager(address(0xdead)));
    }

    function testGetLimitsForTiersWithKYCProvider() public {
        ZkBobAccounting.Limits memory limits;

        SimpleKYCProviderManager manager = _setKYCPorviderManager();
        ERC721PresetMinterPauserAutoId nft = ERC721PresetMinterPauserAutoId(address(manager.NFT()));

        pool.setLimits({
            _tier: 0,
            _tvlCap: 1000 gwei,
            _dailyDepositCap: 500 gwei,
            _dailyWithdrawalCap: 400 gwei,
            _dailyUserDepositCap: 300 gwei,
            _depositCap: 150 gwei,
            _dailyUserDirectDepositCap: 0,
            _directDepositCap: 0
        });

        pool.setLimits({
            _tier: 1,
            _tvlCap: 900 gwei,
            _dailyDepositCap: 400 gwei,
            _dailyWithdrawalCap: 300 gwei,
            _dailyUserDepositCap: 200 gwei,
            _depositCap: 100 gwei,
            _dailyUserDirectDepositCap: 0,
            _directDepositCap: 0
        });

        pool.setLimits({
            _tier: TIER_FOR_KYC,
            _tvlCap: 500 gwei,
            _dailyDepositCap: 250 gwei,
            _dailyWithdrawalCap: 200 gwei,
            _dailyUserDepositCap: 150 gwei,
            _depositCap: 75 gwei,
            _dailyUserDirectDepositCap: 0,
            _directDepositCap: 0
        });

        // Test 1: Limits for the user passed KYC but without a dedicated tier
        uint256 tokenId = _mintNFT(nft, user3);

        limits = pool.getLimitsFor(user3);
        assertEq(limits.tvlCap, 500 gwei);
        assertEq(limits.dailyDepositCap, 250 gwei);
        assertEq(limits.dailyWithdrawalCap, 200 gwei);
        assertEq(limits.dailyUserDepositCap, 150 gwei);
        assertEq(limits.depositCap, 75 gwei);

        // Test 2: Limits for the user passed KYC and with a dedicated tier
        uint256 unused_tokenId = _mintNFT(nft, user2);
        pool.setUserTier(1, user2);

        limits = pool.getLimitsFor(user2);
        assertEq(limits.tvlCap, 900 gwei);
        assertEq(limits.dailyDepositCap, 400 gwei);
        assertEq(limits.dailyWithdrawalCap, 300 gwei);
        assertEq(limits.dailyUserDepositCap, 200 gwei);
        assertEq(limits.depositCap, 100 gwei);

        // Test 3: Limits for the user passed KYC initially and revoked later
        vm.prank(user3);
        nft.burn(tokenId);

        limits = pool.getLimitsFor(user3);
        assertEq(limits.tvlCap, 1000 gwei);
        assertEq(limits.dailyDepositCap, 500 gwei);
        assertEq(limits.dailyWithdrawalCap, 400 gwei);
        assertEq(limits.dailyUserDepositCap, 300 gwei);
        assertEq(limits.depositCap, 150 gwei);
    }

    function testKYCProviderManageSetButNoTier() public {
        ZkBobAccounting.Limits memory limits;

        SimpleKYCProviderManager manager = _setKYCPorviderManager();
        ERC721PresetMinterPauserAutoId nft = ERC721PresetMinterPauserAutoId(address(manager.NFT()));

        uint256 unused_tokenId = _mintNFT(nft, user3);

        limits = pool.getLimitsFor(user3);
        assertEq(limits.tvlCap, 1000 gwei);
        assertEq(limits.dailyDepositCap, 1000 gwei);
        assertEq(limits.dailyWithdrawalCap, 1000 gwei);
        assertEq(limits.dailyUserDepositCap, 1000 gwei);
        assertEq(limits.depositCap, 1000 gwei);
    }

    function testPoolLimitsTiersWithKYCProvider() public {
        ZkBobAccounting.Limits memory limits;

        SimpleKYCProviderManager manager = _setKYCPorviderManager();
        ERC721PresetMinterPauserAutoId nft = ERC721PresetMinterPauserAutoId(address(manager.NFT()));

        pool.setLimits({
            _tier: 0,
            _tvlCap: 160 gwei,
            _dailyDepositCap: 70 gwei,
            _dailyWithdrawalCap: 100 gwei,
            _dailyUserDepositCap: 15 gwei,
            _depositCap: 10 gwei,
            _dailyUserDirectDepositCap: 0,
            _directDepositCap: 0
        });

        pool.setLimits({
            _tier: 1,
            _tvlCap: 160 gwei,
            _dailyDepositCap: 60 gwei,
            _dailyWithdrawalCap: 100 gwei,
            _dailyUserDepositCap: 60 gwei,
            _depositCap: 40 gwei,
            _dailyUserDirectDepositCap: 0,
            _directDepositCap: 0
        });

        pool.setLimits({
            _tier: TIER_FOR_KYC,
            _tvlCap: 145 gwei,
            _dailyDepositCap: 85 gwei,
            _dailyWithdrawalCap: 100 gwei,
            _dailyUserDepositCap: 50 gwei,
            _depositCap: 25 gwei,
            _dailyUserDirectDepositCap: 0,
            _directDepositCap: 0
        });

        // TVL == 0, Tier 0: 0/70, Tier 1: 0/60, Tier 254: 0/85
        // Test 1 (combined with Test 2): Limits changes if KYC token is issued for the user
        pool.recordOperation(IZkBobAccounting.TxType.Common, user3, 1 gwei); // user caps: 1/15
        vm.expectRevert("ZkBobAccounting: single deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user3, 11 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.Common, user3, 10 gwei); // user caps: 11/15
        vm.expectRevert("ZkBobAccounting: daily user deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user3, 5 gwei);

        uint256 unused_tokenId = _mintNFT(nft, user3); // user caps extended - 11/50

        // TVL == 11, Tier 0: 11/70, Tier 1: 0/60, Tier 254: 0/85
        // Test 2: The user with passed KYC (but without a dedicated tier) is able to transact within
        //         limits specified in the KYC-contolled tier
        pool.recordOperation(IZkBobAccounting.TxType.Common, user3, 11 gwei); // user caps: 22/50

        // TVL == 22, Tier 0: 11/70, Tier 1: 0/60, Tier 254: 11/85
        // Test 3: The user with passed KYC (but without a dedicated tier) is not able to transact above
        //         single deposit limit specified in the KYC-contolled tier
        vm.expectRevert("ZkBobAccounting: single deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user3, 26 gwei);

        // TVL == 22, Tier 0: 11/70, Tier 1: 0/60, Tier 254: 11/85
        // Test 4: The user with passed KYC (but without a dedicated tier) is not able to transact above
        //         the daily limit of all single user deposits specified in the KYC-contolled tier
        pool.recordOperation(IZkBobAccounting.TxType.Common, user3, 25 gwei); // user caps: 47/50
        vm.expectRevert("ZkBobAccounting: daily user deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user3, 4 gwei);
        pool.recordOperation(IZkBobAccounting.TxType.Common, user3, 3 gwei); // user caps: 50/50

        // TVL == 50, Tier 0: 11/70, Tier 1: 0/60, Tier 254: 39/85
        // Test 4: The user with passed KYC (but without a dedicated tier) is not able to transact above
        //         the daily limit of all deposits within specified in the KYC-contolled tier
        uint256 tokenId = _mintNFT(nft, user4);

        pool.recordOperation(IZkBobAccounting.TxType.Common, user4, 25 gwei); // user caps: 25/50
        pool.recordOperation(IZkBobAccounting.TxType.Common, user4, 1 gwei); // user caps: 26/50
        vm.expectRevert("ZkBobAccounting: daily deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user4, 22 gwei);

        // TVL == 76, Tier 0: 11/70, Tier 1: 0/60, Tier 254: 65/85
        // Test 5: The user with passed KYC an with a dedicated tier is not able to transact above
        //         the limits specified in the KYC-contolled tier
        pool.setUserTier(1, user2);
        unused_tokenId = _mintNFT(nft, user2); // user caps are not affected

        pool.recordOperation(IZkBobAccounting.TxType.Common, user2, 40 gwei); // user caps: 40/60
        pool.recordOperation(IZkBobAccounting.TxType.Common, user2, 20 gwei); // user caps: 60/60

        // TVL == 136, Tier 0: 11/70, Tier 1: 60/60, Tier 254: 65/85
        // Test 6: The user with passed KYC (but without a dedicated tier) is not able to transact above
        //         the TVL locked limit specified in the KYC-contolled tier
        vm.expectRevert("ZkBobAccounting: tvl cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user4, 10 gwei);

        // TVL == 136, Tier 0: 11/70, Tier 1: 60/60, Tier 254: 65/85
        // Test 7: Limits for the user with passed KYC initially and revoked later, will be replaced by
        //         the default tier's limits. As soon as KYC confirmed again, the limits are recovered.
        pool.recordOperation(IZkBobAccounting.TxType.Common, user4, 1 gwei); // user caps: 27/50
        vm.prank(user4);
        nft.burn(tokenId); // caps are reset to default tier - 27/15
        vm.expectRevert("ZkBobAccounting: daily user deposit cap exceeded");
        pool.recordOperation(IZkBobAccounting.TxType.Common, user4, 1 gwei);
        tokenId = _mintNFT(nft, user4); // user caps extended - 27/50
        pool.recordOperation(IZkBobAccounting.TxType.Common, user4, 1 gwei); // user caps: 28/50

        // TVL == 138, Tier 0: 11/70, Tier 1: 60/60, Tier 254: 67/85
        // Test 7: Limits for the user with passed KYC initially and revoked later, will be replaced by
        //         the default tier's limits. Counters will be restarted at the next day. And as soon
        //         as KYC confirmed again, the limits for the KYC-contolled tier are applied.
        pool.recordOperation(IZkBobAccounting.TxType.Common, user2, -20 gwei); // unwind TVL a bit

        vm.prank(user4);
        nft.burn(tokenId); // caps are reset to default tier - 27/15
        vm.warp(block.timestamp + 1 days); // Counters restart:
            // TVL == 118, Tier 0: 0/70, Tier 1: 0/60, Tier 254: 0/85
        pool.recordOperation(IZkBobAccounting.TxType.Common, user4, 10 gwei); // user caps: 10/15
        tokenId = _mintNFT(nft, user4); // user caps extended - 10/50
        pool.recordOperation(IZkBobAccounting.TxType.Common, user4, 10 gwei); // user caps: 20/50
    }

    function testPoolLimitsTooLarge() public {
        vm.expectRevert("ZkBobAccounting: tvl cap too large");
        pool.setLimits(0, 1e18 gwei, 500 gwei, 400 gwei, 300 gwei, 150 gwei, 0, 0);
        vm.expectRevert("ZkBobAccounting: daily deposit cap too large");
        pool.setLimits(0, 1e16 gwei, 1e10 gwei, 400 gwei, 300 gwei, 150 gwei, 0, 0);
        vm.expectRevert("ZkBobAccounting: daily withdrawal cap too large");
        pool.setLimits(0, 1e16 gwei, 500 gwei, 1e10 gwei, 300 gwei, 150 gwei, 0, 0);
    }
}
