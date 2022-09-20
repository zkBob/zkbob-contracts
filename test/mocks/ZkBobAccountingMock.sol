// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../src/zkbob/utils/ZkBobAccounting.sol";

contract ZkBobAccountingMock is ZkBobAccounting {
    uint256 tvl;
    uint56 public weekMaxTvl;
    uint32 public weekMaxCount;
    uint256 public txCount;

    function slot0() external view returns (bytes32 res) {
        assembly {
            res := sload(0)
        }
    }

    function transact(int256 _amount) external {
        (weekMaxTvl, weekMaxCount, txCount) = _recordOperation(msg.sender, _amount / 1 gwei);
    }

    function setLimits(
        uint256 _tvlCap,
        uint256 _dailyDepositCap,
        uint256 _dailyWithdrawalCap,
        uint256 _dailyUserDepositCap,
        uint256 _depositCap
    ) external {
        _setLimits(
            _tvlCap / 1 gwei,
            _dailyDepositCap / 1 gwei,
            _dailyWithdrawalCap / 1 gwei,
            _dailyUserDepositCap / 1 gwei,
            _depositCap / 1 gwei
        );
    }
}
