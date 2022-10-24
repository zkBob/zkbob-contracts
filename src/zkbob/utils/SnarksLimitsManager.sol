// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

contract SnarksLimitsManager {
    struct SnarksLimits {
        uint256 dailyTurnoverCap;
        uint256 transferCap;
        uint256 outNoteMinCap;
    }

    SnarksLimits private snarksLimits;

    function _setSnarksLimits(
        uint256 _dailyTurnoverCap,
        uint256 _transferCap,
        uint256 _outNoteMinCap
    )
        internal
    {
        // TODO: add size checks
        snarksLimits = SnarksLimits({
            dailyTurnoverCap: _dailyTurnoverCap,
            transferCap: _transferCap,
            outNoteMinCap: _outNoteMinCap
        });
    }

    function getSnarksLimits() public view returns (SnarksLimits memory) {
        return snarksLimits;
    }
}