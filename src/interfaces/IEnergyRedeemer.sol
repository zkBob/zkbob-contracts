// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

interface IEnergyRedeemer {
    function redeem(address _to, uint256 _energy) external;

    function R() external view returns (uint96);

    function calculateRedemptionRate() external view returns (uint256);

    function maxRedeemAmount() external view returns (uint256);
}
