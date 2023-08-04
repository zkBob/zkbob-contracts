// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "../interfaces/IATokenVault.sol";
import "./ZkBobPool.sol";

/**
 * @title ZkBobERC4626Extended
 */
abstract contract ZkBobERC4626Extended is ZkBobPool {
    function _beforeWithdrawal(uint256 _tokenAmount) internal override returns (address, uint256) {
        uint256 amount = IATokenVault(token).redeem(_tokenAmount, address(this), address(this));
        address token_out = address(IATokenVault(token).UNDERLYING());
        return (token_out, amount);
    }
}
