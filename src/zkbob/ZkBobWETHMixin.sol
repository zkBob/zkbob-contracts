// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ZkBobPool.sol";

/**
 * @title ZkBobWETHMixin
 */
abstract contract ZkBobWETHMixin is ZkBobPool {
    // @inheritdoc ZkBobPool
    function _withdrawNative(address _token, address _user, uint256 _tokenAmount) internal override returns (uint256) {
        IWETH9(_token).withdraw(_tokenAmount);
        if (!payable(_user).send(_tokenAmount)) {
            IWETH9(_token).deposit{value: _tokenAmount}();
            IWETH9(_token).transfer(_user, _tokenAmount);
        }
        return _tokenAmount;
    }

    function checkOnReceivingETH() internal virtual {
        require(msg.sender == address(token), "Not a WETH withdrawal");
    }

    receive() external payable {
        checkOnReceivingETH();
    }
}
