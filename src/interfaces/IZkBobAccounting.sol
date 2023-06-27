// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

import "./IKycProvidersManager.sol";

interface IZkBobAccounting {
    enum TxType {
        Common,
        DirectDeposit,
        AppendDirectDeposits
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

    function slot0()
        external
        view
        returns (
            uint56 maxWeeklyAvgTvl,
            uint32 maxWeeklyTxCount,
            uint24 tailSlot,
            uint24 headSlot,
            uint88 cumTvl,
            uint32 txCount
        );

    function recordOperation(TxType _txType, address _user, int256 _txAmount) external;

    function kycProvidersManager() external view returns (IKycProvidersManager);

    function getLimitsFor(address _user) external view returns (Limits memory);
}
