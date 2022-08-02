// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

interface ILegacyERC20 {
    function approve(address spender, uint256 amount) external; // returns (bool);
}
