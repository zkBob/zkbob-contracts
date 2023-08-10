// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "../interfaces/IZkBobDirectDepositsETH.sol";
import "./ZkBobDirectDepositQueueAbs.sol";

/**
 * @title ZkBobDirectDepositQueueETH
 * Queue for zkBob ETH direct deposits.
 */
abstract contract ZkBobDirectDepositETHMixin is IZkBobDirectDepositsETH, ZkBobDirectDepositQueueAbs {
    /// @inheritdoc IZkBobDirectDepositsETH
    function directNativeDeposit(
        address _fallbackUser,
        string calldata _zkAddress
    )
        external
        payable
        returns (uint256)
    {
        return directNativeDeposit(_fallbackUser, bytes(_zkAddress));
    }

    /// @inheritdoc IZkBobDirectDepositsETH
    function directNativeDeposit(
        address _fallbackUser,
        bytes memory _rawZkAddress
    )
        public
        payable
        virtual
        returns (uint256)
    {
        uint256 amount = msg.value;
        IWETH9(token).deposit{value: amount}();
        return _recordDirectDeposit(msg.sender, _fallbackUser, amount, _rawZkAddress);
    }
}
