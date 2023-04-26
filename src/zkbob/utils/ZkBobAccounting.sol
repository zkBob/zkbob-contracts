// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../interfaces/IKycProvidersManager.sol";
import "./KycProvidersManagerStorage.sol";

/**
 * @title ZkBobAccounting
 * @dev On chain accounting for zkBob operations, limits and stats.
 * Units: 1 BOB = 1e18 wei = 1e9 zkBOB units
 * Limitations: Contract will only work correctly as long as pool tvl does not exceed 4.7e12 BOB (4.7 trillion)
 * and overall transaction count does not exceed 4.3e9 (4.3 billion). Pool usage limits cannot exceed 4.3e9 BOB (4.3 billion) per day.
 */
contract ZkBobAccounting is KycProvidersManagerStorage {
    uint256 internal constant SLOT_DURATION = 1 hours;
    uint256 internal constant DAY_SLOTS = 1 days / SLOT_DURATION;
    uint256 internal constant WEEK_SLOTS = 1 weeks / SLOT_DURATION;

    uint256 internal immutable PRECISION;

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
    }

    struct Tier {
        TierLimits limits;
        TierStats stats;
    }

    struct TierLimits {
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
        // max cap on a single deposit (granularity of 1e9)
        // max possible cap - type(uint32).max * 1e9 zkBOB units ~= 4.3e9 BOB
        uint32 depositCap;
        // max cap on a single direct deposit (granularity of 1e9)
        // max possible cap - type(uint32).max * 1e9 zkBOB units ~= 4.3e9 BOB
        uint32 directDepositCap;
        // max cap on the daily direct deposits sum for single user (granularity of 1e9)
        // max possible cap - type(uint32).max * 1e9 zkBOB units ~= 4.3e9 BOB
        uint32 dailyUserDirectDepositCap;
    }

    struct TierStats {
        uint16 day; // last update day number
        uint72 dailyDeposit; // sum of all deposits during given day
        uint72 dailyWithdrawal; // sum of all withdrawals during given day
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
        uint72 dailyDirectDeposit; // sum of user direct deposits during given day
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
        uint256 dailyUserDirectDepositCap;
        uint256 dailyUserDirectDepositCapUsage;
        uint256 directDepositCap;
    }

    Slot0 private slot0;
    Slot1 private slot1;
    mapping(uint256 => Tier) private tiers; // pool limits and usage per tier
    mapping(uint256 => Snapshot) private snapshots; // single linked list of hourly snapshots
    mapping(address => UserStats) private userStats;

    event UpdateLimits(uint8 indexed tier, TierLimits limits);
    event UpdateTier(address user, uint8 tier);

    constructor(uint256 _precision) {
        PRECISION = _precision;
    }

    /**
     * @dev Returns currently configured limits and remaining quotas for the given user as of the current block.
     * @param _user user for which to retrieve limits.
     * @return limits (denominated in zkBOB units = 1e-9 BOB)
     */
    function getLimitsFor(address _user) external view returns (Limits memory) {
        Slot1 memory s1 = slot1;
        UserStats memory us = userStats[_user];
        uint8 tier = _adjustConfiguredTierForUser(_user, us.tier);
        Tier storage t = tiers[tier];
        TierLimits memory tl = t.limits;
        TierStats memory ts = t.stats;
        uint24 curSlot = uint24(block.timestamp / SLOT_DURATION);
        uint24 today = curSlot / uint24(DAY_SLOTS);
        return Limits({
            tvlCap: tl.tvlCap * PRECISION,
            tvl: s1.tvl,
            dailyDepositCap: tl.dailyDepositCap * PRECISION,
            dailyDepositCapUsage: (ts.day == today) ? ts.dailyDeposit : 0,
            dailyWithdrawalCap: tl.dailyWithdrawalCap * PRECISION,
            dailyWithdrawalCapUsage: (ts.day == today) ? ts.dailyWithdrawal : 0,
            dailyUserDepositCap: tl.dailyUserDepositCap * PRECISION,
            dailyUserDepositCapUsage: (us.day == today) ? us.dailyDeposit : 0,
            depositCap: tl.depositCap * PRECISION,
            tier: tier,
            dailyUserDirectDepositCap: tl.dailyUserDirectDepositCap * PRECISION,
            dailyUserDirectDepositCapUsage: (us.day == today) ? us.dailyDirectDeposit : 0,
            directDepositCap: tl.directDepositCap * PRECISION
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
            s0.headSlot = curSlot;
        }

        // update head stats
        s0.cumTvl += s1.tvl / uint72(PRECISION);
        s0.txCount++;

        if (_txAmount != 0) {
            _processTVLChange(s1, _user, _txAmount);
        }

        slot0 = s0;
        return (s0.maxWeeklyAvgTvl, s0.maxWeeklyTxCount, txCount);
    }

    function _processTVLChange(Slot1 memory s1, address _user, int256 _txAmount) internal {
        uint16 curDay = uint16(block.timestamp / SLOT_DURATION / DAY_SLOTS);

        UserStats memory us = userStats[_user];
        Tier storage t = tiers[_adjustConfiguredTierForUser(_user, us.tier)];
        TierLimits memory tl = t.limits;
        TierStats memory ts = t.stats;

        if (_txAmount > 0) {
            uint256 depositAmount = uint256(_txAmount);
            s1.tvl += uint72(depositAmount);

            // check all sorts of limits when processing a deposit
            require(depositAmount <= uint256(tl.depositCap) * PRECISION, "ZkBobAccounting: single deposit cap exceeded");
            require(uint256(s1.tvl) <= uint256(tl.tvlCap) * PRECISION, "ZkBobAccounting: tvl cap exceeded");

            if (curDay > us.day) {
                // user snapshot is outdated, day number and daily sum could be reset
                // original user's tier (0) is preserved
                userStats[_user] =
                    UserStats({day: curDay, dailyDeposit: uint72(depositAmount), tier: us.tier, dailyDirectDeposit: 0});
            } else {
                us.dailyDeposit += uint72(depositAmount);
                require(
                    uint256(us.dailyDeposit) <= uint256(tl.dailyUserDepositCap) * PRECISION,
                    "ZkBobAccounting: daily user deposit cap exceeded"
                );
                userStats[_user] = us;
            }

            if (curDay > ts.day) {
                // latest deposit was on an earlier day, reset daily withdrawal sum
                ts = TierStats({day: curDay, dailyDeposit: uint72(depositAmount), dailyWithdrawal: 0});
            } else {
                ts.dailyDeposit += uint72(depositAmount);
                require(
                    uint256(ts.dailyDeposit) <= uint256(tl.dailyDepositCap) * PRECISION,
                    "ZkBobAccounting: daily deposit cap exceeded"
                );
            }
        } else {
            uint256 withdrawAmount = uint256(-_txAmount);
            require(withdrawAmount <= type(uint32).max * PRECISION, "ZkBobAccounting: withdrawal amount too large");
            s1.tvl -= uint72(withdrawAmount);

            if (curDay > ts.day) {
                // latest withdrawal was on an earlier day, reset daily deposit sum
                ts = TierStats({day: curDay, dailyDeposit: 0, dailyWithdrawal: uint72(withdrawAmount)});
            } else {
                ts.dailyWithdrawal += uint72(withdrawAmount);
                require(
                    uint256(ts.dailyWithdrawal) <= uint256(tl.dailyWithdrawalCap) * PRECISION,
                    "ZkBobAccounting: daily withdrawal cap exceeded"
                );
            }
        }

        slot1 = s1;
        t.stats = ts;
    }

    function _checkDirectDepositLimits(address _user, uint256 _amount) internal {
        uint16 curDay = uint16(block.timestamp / SLOT_DURATION / DAY_SLOTS);

        UserStats memory us = userStats[_user];
        TierLimits memory tl = tiers[_adjustConfiguredTierForUser(_user, us.tier)].limits;

        // check all sorts of limits when processing a deposit
        require(
            _amount <= uint256(tl.directDepositCap) * PRECISION, "ZkBobAccounting: single direct deposit cap exceeded"
        );

        if (curDay > us.day) {
            // user snapshot is outdated, day number and daily sum could be reset
            // original user's tier (0) is preserved
            us = UserStats({day: curDay, dailyDeposit: 0, tier: us.tier, dailyDirectDeposit: uint72(_amount)});
        } else {
            us.dailyDirectDeposit += uint72(_amount);
            require(
                uint256(us.dailyDirectDeposit) <= uint256(tl.dailyUserDirectDepositCap) * PRECISION,
                "ZkBobAccounting: daily user direct deposit cap exceeded"
            );
        }
        userStats[_user] = us;
    }

    function _processDirectDepositBatch(uint256 _totalAmount) internal returns (uint256) {
        slot1.tvl += uint72(_totalAmount);
        return slot0.txCount++;
    }

    function _resetDailyLimits(uint8 _tier) internal {
        delete tiers[_tier].stats;
    }

    function _setLimits(
        uint8 _tier,
        uint256 _tvlCap,
        uint256 _dailyDepositCap,
        uint256 _dailyWithdrawalCap,
        uint256 _dailyUserDepositCap,
        uint256 _depositCap,
        uint256 _dailyUserDirectDepositCap,
        uint256 _directDepositCap
    )
        internal
    {
        require(_tier < 255, "ZkBobAccounting: invalid limit tier");
        require(_depositCap > 0, "ZkBobAccounting: zero deposit cap");
        require(_tvlCap <= type(uint56).max * PRECISION, "ZkBobAccounting: tvl cap too large");
        require(_dailyDepositCap <= type(uint32).max * PRECISION, "ZkBobAccounting: daily deposit cap too large");
        require(_dailyWithdrawalCap <= type(uint32).max * PRECISION, "ZkBobAccounting: daily withdrawal cap too large");
        require(_dailyUserDepositCap >= _depositCap, "ZkBobAccounting: daily user deposit cap too low");
        require(_dailyDepositCap >= _dailyUserDepositCap, "ZkBobAccounting: daily deposit cap too low");
        require(_tvlCap >= _dailyDepositCap, "ZkBobAccounting: tvl cap too low");
        require(_dailyWithdrawalCap > 0, "ZkBobAccounting: zero daily withdrawal cap");
        require(
            _dailyUserDirectDepositCap >= _directDepositCap, "ZkBobAccounting: daily user direct deposit cap too low"
        );
        TierLimits memory tl = TierLimits({
            tvlCap: uint56(_tvlCap / PRECISION),
            dailyDepositCap: uint32(_dailyDepositCap / PRECISION),
            dailyWithdrawalCap: uint32(_dailyWithdrawalCap / PRECISION),
            dailyUserDepositCap: uint32(_dailyUserDepositCap / PRECISION),
            depositCap: uint32(_depositCap / PRECISION),
            dailyUserDirectDepositCap: uint32(_dailyUserDirectDepositCap / PRECISION),
            directDepositCap: uint32(_directDepositCap / PRECISION)
        });
        tiers[_tier].limits = tl;
        emit UpdateLimits(_tier, tl);
    }

    // Tier is set as per the KYC Providers Manager recomendation only in the case if no
    // specific tier assigned to the user
    function _adjustConfiguredTierForUser(address _user, uint8 _configuredTier) internal view returns (uint8) {
        IKycProvidersManager kycProvidersMgr = kycProvidersManager();
        if (_configuredTier == 0 && address(kycProvidersMgr) != address(0)) {
            (bool kycPassed, uint8 tier) = kycProvidersMgr.getIfKYCpassedAndTier(_user);
            if (kycPassed && tiers[tier].limits.tvlCap > 0) {
                return tier;
            }
        }
        return _configuredTier;
    }

    function _setUsersTier(uint8 _tier, address[] memory _users) internal {
        require(
            _tier == 255 || tiers[uint256(_tier)].limits.tvlCap > 0, "ZkBobAccounting: non-existing pool limits tier"
        );
        for (uint256 i = 0; i < _users.length; ++i) {
            address user = _users[i];
            userStats[user].tier = _tier;
            emit UpdateTier(user, _tier);
        }
    }

    function _txCount() internal view returns (uint256) {
        return slot0.txCount;
    }
}
