// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IATokenVault.sol";
import "./ZkBobDirectDepositQueueAbs.sol";

/**
 * @title ZkBobDirectDepositQueueETH
 * Queue for zkBob ETH direct deposits.
 */
abstract contract ZkBobDirectDepositERC4626Mixin is ZkBobDirectDepositQueueAbs {
    using SafeERC20 for IERC20;

    function _receiveTokensFromSender(address _from, uint256 _assets) internal override returns (uint256 shares) {
        IERC20 underlying = IERC20(IATokenVault(token).UNDERLYING());
        underlying.safeTransferFrom(_from, address(this), _assets);
        underlying.approve(token, _assets);
        shares = IATokenVault(token).deposit(_assets, address(this));
    }

    function _sendTokensToFallbackReceiver(address _to, uint256 _shares) internal override returns (uint256 assets) {
        assets = IATokenVault(token).redeem(_shares, address(this), _to);
    }

    function _adjustFees(uint64 _fees, uint256 _shares) internal view override returns (uint64) {
        uint256 assets = IATokenVault(token).previewRedeem(_shares);
        uint256 rate = assets * 1 ether / _shares;
        // Convert assets to shares
        uint256 converted = uint256(_fees) * 1 ether / rate;
        return uint64(converted);
    }
}
