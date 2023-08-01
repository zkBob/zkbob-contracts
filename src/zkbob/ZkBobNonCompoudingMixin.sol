// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ZkBobPool.sol";

/**
 * @title ZkBobNonCompoundingMixin
 */
abstract contract ZkBobNonCompoundingMixin is ZkBobPool {
    using SafeERC20 for IERC20;

    // @inheritdoc ZkBobPool
    function _withdrawToken(address _user, uint256 _tokenAmount) internal override {
        IERC20(token).safeTransfer(_user, _tokenAmount);
    }
}
