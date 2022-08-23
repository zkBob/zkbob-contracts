// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

uint256 constant PRECISION = 1 gwei;
uint256 constant SLOT_DURATION = 1 hours;
uint256 constant DAY_SLOTS = 1 days / SLOT_DURATION;
uint256 constant WEEK_SLOTS = 1 weeks / SLOT_DURATION;

/**
 * @title ZkBobAccounting
 * @dev On chain accounting for zkBob operations, limits and stats.
 * Units: 1 BOB = 1e18 wei = 1e9 zkBOB units
 * Limitations: Contract will only work correctly as long as pool tvl does not exceed 4.7e12 BOB (4.7 trillion)
 * and overall transaction count does not exceed 4.3e9 (4.3 billion). Pool usage limits cannot exceed 4.3e9 BOB (4.3 billion) per day.
 */
contract ZkBobAccounting {
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
        // max cap on the entire pool tvl (granularity of 1e9)
        // max possible cap - type(uint56).max * 1e9 zkBOB units ~= 7.2e16 BOB
        uint56 tvlCap;
        // today deposit sum (granularity of 1e9)
        // max possible sum - type(uint32).max * 1e9 zkBOB units ~= 4.3e9 BOB
        uint32 dailyDeposit;
        // max cap on the daily deposits sum (granularity of 1e9)
        // max possible cap - type(uint32).max * 1e9 zkBOB units ~= 4.3e9 BOB
        uint32 dailyDepositCap;
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

    struct UserDailyStats {
        uint16 day; // last update day number
        uint72 dailyDeposit; // sum of user deposits during given day
    }

    Slot0 private slot0;
    Slot1 private slot1;
    mapping(uint256 => Snapshot) private snapshots; // single linked list of hourly snapshots
    mapping(address => UserDailyStats) private userStats;

    function _recordOperation(address _user, int256 _txAmount)
        internal
        returns (uint56 maxWeeklyAvgTvl, uint32 maxWeeklyTxCount, uint256 txCount)
    {
        Slot0 memory s0 = slot0;
        Slot1 memory s1 = slot1;
        uint24 curSlot = uint24(block.timestamp / SLOT_DURATION);
        uint16 curDay = uint16(curSlot / DAY_SLOTS);
        txCount = uint256(s0.txCount);

        if (s0.txCount > 0 && curSlot - s0.tailSlot > WEEK_SLOTS) {
            // if tail is more than 1 week behind, we move tail pointer to the next snapshot
            Snapshot memory sn = snapshots[s0.tailSlot];
            delete snapshots[s0.tailSlot];
            s0.tailSlot = sn.nextSlot;
            uint32 txCount = s0.txCount - sn.txCount;
            if (txCount > s0.maxWeeklyTxCount) {
                s0.maxWeeklyTxCount = txCount;
            }
            uint56 avgTvl = uint56((s0.cumTvl - sn.cumTvl) / txCount);
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

        if (_txAmount > 0) {
            uint256 depositAmount = uint256(_txAmount);
            s1.tvl += uint72(depositAmount);

            // check all sorts of limits when processing a deposit
            require(depositAmount <= uint256(s1.depositCap) * PRECISION, "ZkBobAccounting: single deposit cap exceeded");
            require(uint256(s1.tvl) <= uint256(s1.tvlCap) * PRECISION, "ZkBobAccounting: tvl cap exceeded");

            UserDailyStats memory us = userStats[_user];
            if (curDay > us.day) {
                // user snapshot is outdated, day number and daily sum could be reset
                userStats[_user] = UserDailyStats(curDay, uint72(depositAmount));
            } else {
                us.dailyDeposit += uint72(depositAmount);
                require(
                    uint256(us.dailyDeposit) <= uint256(s1.dailyUserDepositCap) * PRECISION,
                    "ZkBobAccounting: daily user deposit cap exceeded"
                );
                userStats[_user] = us;
            }

            if (curDay > s0.headSlot / DAY_SLOTS) {
                // latest deposit was on an earlier day, reset daily deposit sum
                s1.dailyDeposit = uint32(depositAmount / PRECISION);
            } else {
                s1.dailyDeposit += uint32(depositAmount / PRECISION);
                require(s1.dailyDeposit <= s1.dailyDepositCap, "ZkBobAccounting: daily deposit cap exceeded");
            }

            slot1 = s1;
        } else if (_txAmount < 0) {
            s1.tvl -= uint72(uint256(-_txAmount));
            slot1 = s1;
        }
        s0.headSlot = curSlot;
        slot0 = s0;
        return (s0.maxWeeklyAvgTvl, s0.maxWeeklyTxCount, txCount);
    }

    function getLimitsFor(address _user) external view returns (uint256[7] memory res) {
        Slot0 memory s0 = slot0;
        Slot1 memory s1 = slot1;
        uint24 curSlot = uint24(block.timestamp / SLOT_DURATION);
        UserDailyStats memory us = userStats[_user];
        res[0] = s1.tvlCap * PRECISION;
        res[1] = s1.tvl;
        res[2] = s1.dailyDepositCap * PRECISION;
        res[3] = (s0.headSlot / DAY_SLOTS == curSlot / DAY_SLOTS) ? s1.dailyDeposit * PRECISION : 0;
        res[4] = s1.dailyUserDepositCap * PRECISION;
        res[5] = (us.day == curSlot / DAY_SLOTS) ? us.dailyDeposit : 0;
        res[6] = s1.depositCap * PRECISION;
    }

    function _setLimits(uint256 _tvlCap, uint256 _dailyDepositCap, uint256 _dailyUserDepositCap, uint256 _depositCap)
        internal
    {
        Slot1 memory s1 = slot1;
        require(_depositCap > 0, "ZkBobAccounting: zero deposit cap");
        require(_dailyUserDepositCap >= _depositCap, "ZkBobAccounting: daily user deposit cap too low");
        require(_dailyDepositCap >= _dailyUserDepositCap, "ZkBobAccounting: daily deposit cap too low");
        require(_tvlCap >= _dailyDepositCap, "ZkBobAccounting: tvl cap too low");
        s1.tvlCap = uint56(_tvlCap / PRECISION);
        s1.dailyDepositCap = uint32(_dailyDepositCap / PRECISION);
        s1.dailyUserDepositCap = uint32(_dailyUserDepositCap / PRECISION);
        s1.depositCap = uint32(_depositCap / PRECISION);
        slot1 = s1;
    }
}