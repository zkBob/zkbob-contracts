// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

interface IBobVault {
    function buy(address _token, uint256 _amount) external returns (uint256);
    function sell(address _token, uint256 _amount) external returns (uint256);
    function swap(address _inToken, address _outToken, uint256 _amount) external returns (uint256);
}
