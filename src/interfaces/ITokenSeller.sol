// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

interface ITokenSeller {
    function sellForETH(address _to, uint256 _amount) external;
}
