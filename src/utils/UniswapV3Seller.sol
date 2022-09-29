// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol";
import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "../interfaces/ITokenSeller.sol";
import "./Sacrifice.sol";

/**
 * @title UniswapV3Seller
 * Helper for selling some token for ETH through a 2-hop UniswapV3 exchange.
 */
contract UniswapV3Seller is ITokenSeller {
    ISwapRouter immutable swapRouter;
    IWETH9 immutable WETH;

    address immutable token0;
    uint24 immutable fee0;
    address immutable token1;
    uint24 immutable fee1;

    constructor(address _swapRouter, address _token0, uint24 _fee0, address _token1, uint24 _fee1) {
        IERC20(_token0).approve(_swapRouter, type(uint256).max);
        swapRouter = ISwapRouter(_swapRouter);
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
     * @param _receiver native ETH receiver.
     * @param _value amount of tokens to sell.
     */
    function sellForETH(address _receiver, uint256 _value) external {
        uint256 amountOut = swapRouter.exactInput(
            ISwapRouter.ExactInputParams({
                path: abi.encodePacked(token0, fee0, token1, fee1, WETH),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: _value,
                amountOutMinimum: 0
            })
        );
        WETH.withdraw(amountOut);
        if (!payable(_receiver).send(amountOut)) {
            new Sacrifice{value: amountOut}(_receiver);
        }
    }
}
