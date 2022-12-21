// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "../interfaces/ITokenSeller.sol";
import "./Sacrifice.sol";

/**
 * @title UniswapV3Seller
 * Helper for selling some token for ETH through a 2-hop UniswapV3 exchange.
 */
contract UniswapV3Seller is ITokenSeller {
    ISwapRouter immutable swapRouter;
    IQuoter immutable quoter;
    IWETH9 immutable WETH;

    address immutable token0;
    uint24 immutable fee0;
    address immutable token1;
    uint24 immutable fee1;

    constructor(address _swapRouter, address _quoter, address _token0, uint24 _fee0, address _token1, uint24 _fee1) {
        IERC20(_token0).approve(_swapRouter, type(uint256).max);
        swapRouter = ISwapRouter(_swapRouter);
        quoter = IQuoter(_quoter);
        WETH = IWETH9(IPeripheryImmutableState(_swapRouter).WETH9());
        token0 = _token0;
        fee0 = _fee0;
        token1 = _token1;
        fee1 = _fee1;
    }

    receive() external payable {
        require(msg.sender == address(WETH), "UniswapV3Seller: not a WETH withdrawal");
    }

    /**
     * @dev Sells tokens for ETH.
     * Prior to calling this function, contract balance of token0 should be greater than or equal to the sold amount.
     * Note: this implementation does not include any slippage/sandwich protection,
     * users are strongly discouraged from using this contract for exchanging significant amounts.
     * @param _receiver native ETH receiver.
     * @param _amount amount of tokens to sell.
     * @return (received eth amount, refunded token amount).
     */
    function sellForETH(address _receiver, uint256 _amount) external returns (uint256, uint256) {
        uint256 balance = IERC20(token0).balanceOf(address(this));
        require(balance >= _amount, "UniswapV3Seller: not enough tokens");

        uint256 amountOut = swapRouter.exactInput(
            ISwapRouter.ExactInputParams({
                path: abi.encodePacked(token0, fee0, token1, fee1, WETH),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: _amount,
                amountOutMinimum: 0
            })
        );
        WETH.withdraw(amountOut);
        if (!payable(_receiver).send(amountOut)) {
            new Sacrifice{value: amountOut}(_receiver);
        }
        uint256 remainingBalance = IERC20(token0).balanceOf(address(this));
        if (remainingBalance + _amount > balance) {
            uint256 refund = remainingBalance + _amount - balance;
            IERC20(token0).transfer(msg.sender, refund);
            return (amountOut, refund);
        }
        return (amountOut, 0);
    }

    /**
     * @dev Estimates amount of received ETH, when selling given amount of tokens via sellForETH function.
     * @param _amount amount of tokens to sell.
     * @return received eth amount.
     */
    function quoteSellForETH(uint256 _amount) external returns (uint256) {
        return quoter.quoteExactInput(abi.encodePacked(token0, fee0, token1, fee1, WETH), _amount);
    }
}
