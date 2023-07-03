// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

contract DecimalAdjustment {
    uint256 internal constant MAX_DENOMINATOR = 0x8000000000000000000000000000000000000000000000000000000000000000 - 1;

    function tokenToPool(uint256 _value, uint256 _denominator) internal pure returns (uint64) {
        if (_denominator <= MAX_DENOMINATOR) {
            return uint64(_value / _denominator);
        } else {
            return uint64(_value * (_denominator & MAX_DENOMINATOR));
        }
    }

    function poolToToken(uint256 _value, uint256 _denominator) internal pure returns (uint256) {
        if (_denominator <= MAX_DENOMINATOR) {
            return _value * _denominator;
        } else {
            return _value / (_denominator & MAX_DENOMINATOR);
        }
    }
}
