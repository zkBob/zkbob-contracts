// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

import "./IZkBobAccounting.sol";

interface IZkBobPool {
    struct ForcedExitParams {
        address to;
        uint64 amount;
        address operator;
        uint40 exitStart;
        uint40 exitEnd;
    }

    function pool_id() external view returns (uint256);

    function denominator() external view returns (uint256);

    function accounting() external view returns (IZkBobAccounting);

    function recordDirectDeposit(address _sender, uint256 _amount) external;
}
