// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../src/zkbob/utils/ZkBobAccounting.sol";

contract ZkBobAccountingMock is ZkBobAccounting(1_000_000_000) {
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

    function setUserTier(uint8 _tier, address _user) external {
        address[] memory users = new address[](1);
        users[0] = _user;
        _setUsersTier(_tier, users);
    }

    function setLimits(
        uint8 _tier,
        uint256 _tvlCap,
        uint256 _dailyDepositCap,
        uint256 _dailyWithdrawalCap,
        uint256 _dailyUserDepositCap,
        uint256 _depositCap,
        uint256 _dailyUserDirectDepositCap,
        uint256 _directDepositCap
    )
        external
    {
        _setLimits(
            _tier,
            _tvlCap / 1 gwei,
            _dailyDepositCap / 1 gwei,
            _dailyWithdrawalCap / 1 gwei,
            _dailyUserDepositCap / 1 gwei,
            _depositCap / 1 gwei,
            _dailyUserDirectDepositCap / 1 gwei,
            _directDepositCap / 1 gwei
        );
    }
}
