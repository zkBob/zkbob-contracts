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

    function passesKYC(address _user) external view override returns (bool) {
        return _checkIfKycPassed(_user);
    }

    // In simple manager it is assumed that one tier is used for all users passed KYC.
    // Also the assumption is that the method either always used after passesKYC or with
    // _checkKYC set to true.
    function getAssociatedLimitsTier(address _user, bool _checkKYC) external view override returns (uint8) {
        if (_checkKYC) {
            require(_checkIfKycPassed(_user), "KYCProviderManager: non-existing pool limits tier");
        }
        return tierForPassedKYC;
    }

    function _checkIfKycPassed(address _user) internal view returns (bool) {
        return NFT.balanceOf(_user) > 0;
    }
}
