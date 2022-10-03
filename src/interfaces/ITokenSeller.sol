// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

interface ITokenSeller {
    /**
     * @dev Sells tokens for ETH.
     * Prior to calling this function, contract balance of token0 should be greater than or equal to the sold amount.
     * @param _receiver native ETH receiver.
     * @param _amount amount of tokens to sell.
     * @return (received eth amount, refunded token amount).
     */
    function sellForETH(address _receiver, uint256 _amount) external returns (uint256, uint256);

    /**
     * @dev Estimates amount of received ETH, when selling given amount of tokens via sellForETH function.
     * @param _amount amount of tokens to sell.
     * @return received eth amount.
     */
    function quoteSellForETH(uint256 _amount) external returns (uint256);
}
