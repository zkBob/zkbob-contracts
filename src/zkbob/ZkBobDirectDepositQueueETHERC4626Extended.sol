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
import "../interfaces/IATokenVault.sol";
import "../utils/Ownable.sol";
import "../proxy/EIP1967Admin.sol";
import "./ZkBobDirectDepositQueueETH.sol";

/**
 * @title ZkBobDirectDepositQueueETHERC4626Extended
 * Queue for ETH direct deposits to ERC4626 based zkBob pool
 */
contract ZkBobDirectDepositQueueETHERC4626Extended is ZkBobDirectDepositQueueETH {
    constructor(
        address _pool,
        address _token,
        uint256 _denominator
    )
        ZkBobDirectDepositQueueETH(_pool, _token, _denominator)
    {}

    /// @inheritdoc IZkBobDirectDepositsETH
    function directNativeDeposit(
        address _fallbackUser,
        bytes memory _rawZkAddress
    )
        public
        payable
        override
        returns (uint256)
    {
        uint256 amount = msg.value;
        IWETH9 weth = IWETH9(IATokenVault(token).UNDERLYING());
        weth.deposit{value: amount}();
        IERC20(address(weth)).approve(token, amount);
        uint256 shares = IATokenVault(token).deposit(amount, address(this));
        return _recordDirectDeposit(msg.sender, _fallbackUser, shares, _rawZkAddress);
    }
}
