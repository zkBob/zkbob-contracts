// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

interface IBurnableERC20 {
    function burn(uint256 amount) external;
    function burnFrom(address user, uint256 amount) external;
}
