// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ZkBobDirectDepositQueueAbs.sol";

/**
 * @title ZkBobDirectDepositQueueETH
 * Queue for zkBob ETH direct deposits.
 */
abstract contract ZkBobDirectDepositDTO is ZkBobDirectDepositQueueAbs {
    using SafeERC20 for IERC20;

    function _receiveTokensFromSender(address _from, uint256 _amount) internal override returns (uint256) {
        IERC20(token).safeTransferFrom(_from, address(this), _amount);
        return _amount;
    }

    function _sendTokensToFallbackReceiver(address _to, uint256 _amount) internal override returns (uint256) {
        IERC20(token).safeTransfer(_to, _amount);
        return _amount;
    }

    function _adjustAmounts(
        uint256 _amount_counted,
        uint256 _amount_sent,
        uint64 _fees
    )
        internal
        view
        override
        returns (uint64 deposit, uint64 fee, uint64 to_record)
    {
        fee = _fees;
        // small amount of wei might get lost during division, this amount will stay in the contract indefinitely
        deposit = uint64(_amount_counted / TOKEN_DENOMINATOR * TOKEN_NUMERATOR);
        require(deposit > fee, "ZkBobDirectDepositQueue: direct deposit amount is too low");
        unchecked {
            deposit -= fee;
        }
        to_record = deposit;
    }
}
