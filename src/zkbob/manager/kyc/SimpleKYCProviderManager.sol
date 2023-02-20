// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../../interfaces/IKycProvidersManager.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title SimpleKYCProviderManager
 * @dev Implements KYC verifier based on specific NFT ownership.
 */
contract SimpleKYCProviderManager is IKycProvidersManager {
    // ownership of a token in this NFT-contract will be checked to consider an account as passed KYC
    IERC721 public immutable NFT;
    // this tier number will be used for all users passed KYC
    uint8 immutable tierForPassedKYC;

    constructor(IERC721 _token, uint8 _tier) {
        require(address(_token) != address(0), "KYCProviderManager: token address is zero");
        NFT = _token;
        tierForPassedKYC = _tier;
    }

    function getIfKYCpassedAndTier(address _user) external view override returns (bool, uint8) {
        bool kycPassed = _checkIfKycPassed(_user);
        uint8 tier = 0;
        if (kycPassed) {
            tier = tierForPassedKYC;
        }
        return (kycPassed, tier);
    }

    function _checkIfKycPassed(address _user) internal view returns (bool) {
        return NFT.balanceOf(_user) > 0;
    }
}
