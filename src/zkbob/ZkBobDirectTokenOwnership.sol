// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ZkBobPool.sol";

/**
 * @title ZkBobDirectTokenOwnership
 */
abstract contract ZkBobDirectTokenOwnership is ZkBobPool {
    function _beforeWithdrawal(uint256 _tokenAmount) internal override returns (address, uint256) {
        return (token, _tokenAmount);
    }
}
