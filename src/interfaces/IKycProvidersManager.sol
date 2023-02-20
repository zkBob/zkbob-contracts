// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

interface IKycProvidersManager {
    function getIfKYCpassedAndTier(address _user) external view returns (bool, uint8);
}
