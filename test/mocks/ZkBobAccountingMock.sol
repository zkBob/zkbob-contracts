// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../src/interfaces/IEnergyRedeemer.sol";

contract ZkBobAccountingMock {
    uint56 maxWeeklyAvgTvl;
    uint32 maxWeeklyTxCount;

    constructor(uint56 _maxWeeklyAvgTvl, uint32 _maxWeeklyTxCount) {
        maxWeeklyAvgTvl = _maxWeeklyAvgTvl;
        maxWeeklyTxCount = _maxWeeklyTxCount;
    }

    function accounting() external view returns (address) {
        return address(this);
    }

    function slot0()
        external
        view
        returns (
            uint56 _maxWeeklyAvgTvl,
            uint32 _maxWeeklyTxCount,
            uint24 _tailSlot,
            uint24 _headSlot,
            uint88 _cumTvl,
            uint32 _txCount
        )
    {
        return (maxWeeklyAvgTvl, maxWeeklyTxCount, 0, 0, 0, 0);
    }

    function redeem(address _redeemer, address _to, uint256 _energy) external {
        IEnergyRedeemer(_redeemer).redeem(_to, _energy);
    }
}
