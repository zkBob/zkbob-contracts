// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

interface IAllowList {
    function isAllowed(uint256 _id, address _user) external view returns (bool);
}
