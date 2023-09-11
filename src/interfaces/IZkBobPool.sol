// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

import "./IZkBobAccounting.sol";

interface IZkBobPool {
    function pool_id() external view returns (uint256);

    function denominator() external view returns (uint256);

    function accounting() external view returns (IZkBobAccounting);

    function recordDirectDeposit(address _sender, uint256 _amount) external;
}
