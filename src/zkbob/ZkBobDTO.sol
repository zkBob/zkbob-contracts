// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ZkBobPool.sol";

/**
 * @title ZkBobDTO
 */
abstract contract ZkBobDTO is ZkBobPool {
    function _beforeWithdrawal(uint256 _tokenAmount) internal view override returns (address, uint256) {
        return (token, _tokenAmount);
    }

    function _adjustPriorRecord(int256 _amount) internal view override returns (int256) {
        return _amount;
    }
}
