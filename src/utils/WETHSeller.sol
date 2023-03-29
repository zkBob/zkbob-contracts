// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "../interfaces/ITokenSeller.sol";
import "./Sacrifice.sol";

/**
 * @title WETHSeller
 * Helper for selling WETH for ETH.
 */
contract WETHSeller is ITokenSeller {
    IWETH9 immutable weth;

    constructor(address _weth) {
        weth = IWETH9(_weth);
    }

    /**
     * @dev Sells WETH for ETH.
     * Prior to calling this function, contract balance of token0 should be greater than or equal to the sold amount.
     * Note: this implementation does not include any slippage/sandwich protection,
     * users are strongly discouraged from using this contract for exchanging significant amounts.
     * @param _receiver native ETH receiver.
     * @param _amount amount of tokens to sell.
     * @return (received eth amount, refunded token amount).
     */
    function sellForETH(address _receiver, uint256 _amount) external returns (uint256, uint256) {
        require(weth.balanceOf(address(this)) >= _amount, "WETHSeller: not enough tokens");
        weth.withdraw(_amount);
        if (!payable(_receiver).send(_amount)) {
            new Sacrifice{value: _amount}(_receiver);
        }
        return (_amount, 0);
    }

    /**
     * @dev Estimates amount of received ETH, when selling given amount of tokens via sellForETH function.
     * @param _amount amount of tokens to sell.
     * @return received eth amount.
     */
    function quoteSellForETH(uint256 _amount) external returns (uint256) {
        return _amount;
    }

    receive() external payable {
        require(msg.sender == address(weth), "WETHSeller: not a WETH withdrawal");
    }
}
