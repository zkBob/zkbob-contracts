// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ZkBobPool.sol";

/**
 * @title ZkBobWETHMixin
 */
abstract contract ZkBobWETHMixin is ZkBobPool {
    // @inheritdoc ZkBobPool
    function _withdrawNative(address _user, uint256 _tokenAmount) internal override returns (uint256) {
        IWETH9(token).withdraw(_tokenAmount);
        if (!payable(_user).send(_tokenAmount)) {
            IWETH9(token).deposit{value: _tokenAmount}();
            IWETH9(token).transfer(_user, _tokenAmount);
        }
        return _tokenAmount;
    }

    receive() external payable {
        require(msg.sender == address(token), "Not a WETH withdrawal");
    }
}
