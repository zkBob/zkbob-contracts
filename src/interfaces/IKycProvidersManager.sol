// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

interface IKycProvidersManager {
    function passesKYC(address _addr) external view returns (bool);
    function getAssociatedLimitsTier(address _addr, bool _checkKYC) external view returns (uint8);
}