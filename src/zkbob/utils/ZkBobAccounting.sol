// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

/**
 * @title ZkBobAccounting
 * @dev On chain accounting for zkBob operations, limits and stats.
 * Units: 1 BOB = 1e18 wei = 1e9 zkBOB units
 * Limitations: Contract will only work correctly as long as pool tvl does not exceed 4.7e12 BOB (4.7 trillion)
 * and overall transaction count does not exceed 4.3e9 (4.3 billion). Pool usage limits cannot exceed 4.3e9 BOB (4.3 billion) per day.
 */
contract ZkBobAccounting {
    uint256 internal constant PRECISION = 1_000_000_000;
    uint256 internal constant SLOT_DURATION = 1 hours;
    uint256 internal constant DAY_SLOTS = 1 days / SLOT_DURATION;
    uint256 internal constant WEEK_SLOTS = 1 weeks / SLOT_DURATION;

    struct Slot0 {
        // max seen average tvl over period of at least 1 week (granularity of 1e9), might not be precise
        // max possible tvl - type(uint56).max * 1e9 zkBOB units ~= 7.2e16 BOB
        uint56 maxWeeklyAvgTvl;
        // max number of pool interactions over 1 week, might not be precise
        // max possible tx count - type(uint32).max ~= 4.3e9 transactions
        uint32 maxWeeklyTxCount;
        // 1 week behind snapshot time slot (granularity of 1 hour)
        // max possible timestamp - Dec 08 3883
        uint24 tailSlot;
        // active snapshot time slot (granularity of 1 hour)
        // max possible timestamp - Dec 08 3883
        uint24 headSlot;
        // cumulative sum of tvl over txCount interactions (granularity of 1e9)
        // max possible cumulative tvl ~= type(uint32).max * type(uint56).max = 4.3e9 transactions * 7.2e16 BOB
        uint88 cumTvl;
        // number of successful pool interactions since launch
        // max possible tx count - type(uint32).max ~= 4.3e9 transactions
        uint32 txCount;
    }

    struct Slot1 {
        // current pool tvl (granularity of 1)
        // max possible tvl - type(uint72).max * 1 zkBOB units ~= 4.7e21 zkBOB units ~= 4.7e12 BOB
        uint72 tvl;
        // today deposit sum (granularity of 1e9)
        // max possible sum - type(uint32).max * 1e9 zkBOB units ~= 4.3e9 BOB
        uint32 dailyDeposit;
        // today withdrawal sum (granularity of 1e9)
        // max possible sum - type(uint32).max * 1e9 zkBOB units ~= 4.3e9 BOB
        uint32 dailyWithdrawal;
    }

    struct PoolLimits {
        // max cap on the entire pool tvl (granularity of 1e9)
        // max possible cap - type(uint56).max * 1e9 zkBOB units ~= 7.2e16 BOB
        uint56 tvlCap;
        // max cap on the daily deposits sum (granularity of 1e9)
        // max possible cap - type(uint32).max * 1e9 zkBOB units ~= 4.3e9 BOB
        uint32 dailyDepositCap;
        // max cap on the daily withdrawal sum (granularity of 1e9)
        // max possible cap - type(uint32).max * 1e9 zkBOB units ~= 4.3e9 BOB
        uint32 dailyWithdrawalCap;
        // max cap on the daily deposits sum for single user (granularity of 1e9)
        // max possible cap - type(uint32).max * 1e9 zkBOB units ~= 4.3e9 BOB
        uint32 dailyUserDepositCap;
        // max cap on single deposit (granularity of 1e9)
        // max possible cap - type(uint32).max * 1e9 zkBOB units ~= 4.3e9 BOB
        uint32 depositCap;
    }

    struct Snapshot {
        uint24 nextSlot; // next slot to from the queue
        uint32 txCount; // number of successful pool interactions since launch at the time of the snapshot
        uint88 cumTvl; // cumulative sum of tvl over txCount interactions (granularity of 1e9)
    }

    struct UserStats {
        uint16 day; // last update day number
        uint72 dailyDeposit; // sum of user deposits during given day
        uint8 tier; // user limits tier, 0 being the default tier
    }

    struct Limits {
        uint256 tvlCap;
        uint256 tvl;
        uint256 dailyDepositCap;
        uint256 dailyDepositCapUsage;
        uint256 dailyWithdrawalCap;
        uint256 dailyWithdrawalCapUsage;
        uint256 dailyUserDepositCap;
        uint256 dailyUserDepositCapUsage;
        uint256 depositCap;
        uint8 tier;
    }

    Slot0 private slot0;
    Slot1 private slot1;
    mapping(uint256 => PoolLimits) private poolLimits; // pool limits per tier
    mapping(uint256 => Snapshot) private snapshots; // single linked list of hourly snapshots
    mapping(address => UserStats) private userStats;

    event UpdateTier(address user, uint8 tier);

    /**
     * @dev Returns currently configured limits and remaining quotas for the given user as of the current block.
     * @param _user user for which to retrieve limits.
     * @return limits (denominated in zkBOB units = 1e-9 BOB)
     */
    function getLimitsFor(address _user) external view returns (Limits memory) {
        Slot0 memory s0 = slot0;
        Slot1 memory s1 = slot1;
        UserStats memory us = userStats[_user];
        PoolLimits memory pl = poolLimits[uint256(us.tier)];
        uint24 curSlot = uint24(block.timestamp / SLOT_DURATION);
        uint24 today = curSlot / uint24(DAY_SLOTS);
        return Limits({
            tvlCap: pl.tvlCap * PRECISION,
            tvl: s1.tvl,
            dailyDepositCap: pl.dailyDepositCap * PRECISION,
            dailyDepositCapUsage: (s0.headSlot / DAY_SLOTS == today) ? s1.dailyDeposit * PRECISION : 0,
            dailyWithdrawalCap: pl.dailyWithdrawalCap * PRECISION,
            dailyWithdrawalCapUsage: (s0.headSlot / DAY_SLOTS == today) ? s1.dailyWithdrawal * PRECISION : 0,
            dailyUserDepositCap: pl.dailyUserDepositCap * PRECISION,
            dailyUserDepositCapUsage: (us.day == today) ? us.dailyDeposit : 0,
            depositCap: pl.depositCap * PRECISION,
            tier: us.tier
        });
    }

    function _recordOperation(
        address _user,
        int256 _txAmount
    )
        internal
        returns (uint56 maxWeeklyAvgTvl, uint32 maxWeeklyTxCount, uint256 txCount)
    {
        Slot0 memory s0 = slot0;
        Slot1 memory s1 = slot1;
        uint24 curSlot = uint24(block.timestamp / SLOT_DURATION);
        txCount = uint256(s0.txCount);

        // for full correctness, next line should use "while" instead of "if"
        // however, in order to keep constant gas usage, "if" is being used
        // this can lead to a longer sliding window (> 1 week) in some cases,
        // but eventually it will converge back to the 1 week target
        if (s0.txCount > 0 && curSlot - s0.tailSlot > WEEK_SLOTS) {
            // if tail is more than 1 week behind, we move tail pointer to the next snapshot
            Snapshot memory sn = snapshots[s0.tailSlot];
            delete snapshots[s0.tailSlot];
            s0.tailSlot = sn.nextSlot;
            uint32 weeklyTxCount = s0.txCount - sn.txCount;
            if (weeklyTxCount > s0.maxWeeklyTxCount) {
                s0.maxWeeklyTxCount = weeklyTxCount;
            }
            uint56 avgTvl = uint56((s0.cumTvl - sn.cumTvl) / weeklyTxCount);
            if (avgTvl > s0.maxWeeklyAvgTvl) {
                s0.maxWeeklyAvgTvl = avgTvl;
            }
        }

        if (s0.headSlot < curSlot) {
            snapshots[s0.headSlot] = Snapshot(curSlot, s0.txCount, s0.cumTvl);
        }

        // update head stats
        s0.cumTvl += s1.tvl / uint72(PRECISION);
        s0.txCount++;

        _processTVLChange(s0, s1, _user, _txAmount);

        s0.headSlot = curSlot;
        slot0 = s0;
        return (s0.maxWeeklyAvgTvl, s0.maxWeeklyTxCount, txCount);
    }

    function _processTVLChange(Slot0 memory s0, Slot1 memory s1, address _user, int256 _txAmount) internal {
        if (_txAmount == 0) {
            return;
        }

        UserStats memory us = userStats[_user];
        PoolLimits memory pl = poolLimits[us.tier];

        uint16 curDay = uint16(block.timestamp / SLOT_DURATION / DAY_SLOTS);

        if (_txAmount > 0) {
            uint256 depositAmount = uint256(_txAmount);
            s1.tvl += uint72(depositAmount);

            // check all sorts of limits when processing a deposit
            require(depositAmount <= uint256(pl.depositCap) * PRECISION, "ZkBobAccounting: single deposit cap exceeded");
            require(uint256(s1.tvl) <= uint256(pl.tvlCap) * PRECISION, "ZkBobAccounting: tvl cap exceeded");

            if (curDay > us.day) {
                // user snapshot is outdated, day number and daily sum could be reset
                userStats[_user] = UserStats(curDay, uint72(depositAmount), us.tier);
            } else {
                us.dailyDeposit += uint72(depositAmount);
                require(
                    uint256(us.dailyDeposit) <= uint256(pl.dailyUserDepositCap) * PRECISION,
                    "ZkBobAccounting: daily user deposit cap exceeded"
                );
                userStats[_user] = us;
            }

            if (curDay > s0.headSlot / DAY_SLOTS) {
                // latest deposit was on an earlier day, reset daily deposit sum
                s1.dailyDeposit = uint32(depositAmount / PRECISION);
            } else {
                s1.dailyDeposit += uint32(depositAmount / PRECISION);
                require(s1.dailyDeposit <= pl.dailyDepositCap, "ZkBobAccounting: daily deposit cap exceeded");
            }
        } else {
            uint256 withdrawAmount = uint256(-_txAmount);
            s1.tvl -= uint72(withdrawAmount);

            if (curDay > s0.headSlot / DAY_SLOTS) {
                // latest withdrawal was on an earlier day, reset daily deposit sum
                s1.dailyWithdrawal = uint32(withdrawAmount / PRECISION);
            } else {
                s1.dailyWithdrawal += uint32(withdrawAmount / PRECISION);
                require(s1.dailyWithdrawal <= pl.dailyWithdrawalCap, "ZkBobAccounting: daily withdrawal cap exceeded");
            }
        }

        slot1 = s1;
    }

    function _setLimits(
        uint8 _tier,
        uint256 _tvlCap,
        uint256 _dailyDepositCap,
        uint256 _dailyWithdrawalCap,
        uint256 _dailyUserDepositCap,
        uint256 _depositCap
    ) internal {
        Slot1 memory s1 = slot1;
        Slot2 memory s2 = slot2;

        require(_tier < 255, "ZkBobAccounting: invalid limit tier");
        require(_depositCap > 0, "ZkBobAccounting: zero deposit cap");
        require(_dailyUserDepositCap >= _depositCap, "ZkBobAccounting: daily user deposit cap too low");
        require(_dailyDepositCap >= _dailyUserDepositCap, "ZkBobAccounting: daily deposit cap too low");
        require(_tvlCap >= _dailyDepositCap, "ZkBobAccounting: tvl cap too low");
        require(_dailyWithdrawalCap > 0, "ZkBobAccounting: zero daily withdrawal cap");
        poolLimits[_tier] = PoolLimits({
            tvlCap: uint56(_tvlCap / PRECISION),
            dailyDepositCap: uint32(_dailyDepositCap / PRECISION),
            dailyWithdrawalCap: uint32(_dailyWithdrawalCap / PRECISION),
            dailyUserDepositCap: uint32(_dailyUserDepositCap / PRECISION),
            depositCap: uint32(_depositCap / PRECISION)
        });
    }

    function _setUsersTier(uint8 _tier, address[] memory _users) internal {
        require(_tier == 255 || poolLimits[uint256(_tier)].tvlCap > 0, "ZkBobAccounting: non-existing pool limits tier");
        for (uint256 i = 0; i < _users.length; i++) {
            address user = _users[i];
            userStats[user].tier = _tier;
            emit UpdateTier(user, _tier);
        }
    }

    function _txCount() internal view returns (uint256) {
        return slot0.txCount;
    }
}
