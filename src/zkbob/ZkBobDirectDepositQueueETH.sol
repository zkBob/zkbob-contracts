// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "../libraries/ZkAddress.sol";
import "../interfaces/IOperatorManager.sol";
import "../interfaces/IZkBobDirectDepositsETH.sol";
import "../interfaces/IZkBobDirectDepositQueue.sol";
import "../interfaces/IZkBobPool.sol";
import "../utils/Ownable.sol";
import "../proxy/EIP1967Admin.sol";
import "./ZkBobDirectDepositQueue.sol";

/**
 * @title ZkBobDirectDepositQueueETH
 * Queue for zkBob ETH direct deposits.
 */
contract ZkBobDirectDepositQueueETH is IZkBobDirectDepositsETH, ZkBobDirectDepositQueue {
    constructor(
        address _pool,
        address _token,
        uint256 _denominator
    )
        ZkBobDirectDepositQueue(_pool, _token, _denominator)
    {}

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
    function directNativeDeposit(address _fallbackUser, bytes memory _rawZkAddress) public payable returns (uint256) {
        uint256 amount = msg.value;
        IWETH9(token).deposit{value: amount}();
        return _recordDirectDeposit(msg.sender, _fallbackUser, amount, _rawZkAddress);
    }
}
