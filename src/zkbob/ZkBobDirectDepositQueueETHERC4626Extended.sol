// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "../interfaces/IZkBobPool.sol";
import "../interfaces/IATokenVault.sol";
import "./ZkBobDirectDepositQueueAbs.sol";
import "./ZkBobDirectDepositETHMixin.sol";
import "./ZkBobDirectDepositERC4626Mixin.sol";

/**
 * @title ZkBobDirectDepositQueueETHERC4626Extended
 * Queue for ETH direct deposits to ERC4626 based zkBob pool
 */
contract ZkBobDirectDepositQueueETHERC4626Extended is
    ZkBobDirectDepositQueueAbs,
    ZkBobDirectDepositETHMixin,
    ZkBobDirectDepositERC4626Mixin
{
    constructor(
        address _pool,
        address _token,
        uint256 _denominator
    )
        ZkBobDirectDepositQueueAbs(_pool, _token, _denominator)
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
        uint256 assets = msg.value;
        IWETH9 weth = IWETH9(IATokenVault(token).UNDERLYING());
        weth.deposit{value: assets}();
        IERC20(address(weth)).approve(token, assets);
        uint256 shares = IATokenVault(token).deposit(assets, address(this));
        return _recordDirectDeposit(msg.sender, _fallbackUser, shares, assets, _rawZkAddress);
    }
}
