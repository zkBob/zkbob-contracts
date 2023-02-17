// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

interface IZkBobPool {
    function pool_id() external view returns (uint256);

    function recordDirectDeposit(address _sender, uint256 _amount) external;
}
