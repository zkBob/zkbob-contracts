// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/Address.sol";
import "../../interfaces/IKycProvidersManager.sol";
import "../../utils/Ownable.sol";

contract KycProvidersManagerStorage is Ownable {
    // In order to avoid shifting storage slots by defining a new variable in
    // the contract, KYC Providers Manager will be accessed through specifying
    // a free slot explicitly. Similar approach is used in EIP1967.
    //
    // bytes32(uint256(keccak256('zkBob.ZkBobAccounting.kycProvidersManager')) - 1)
    uint256 internal constant KYC_PROVIDER_MANAGER_STORAGE =
        0x06c991646992b7f0f3fd0c832eac3f519e26682bcb82fbbcfd1ff8013d876f64;

    event UpdateKYCProvidersManager(address manager);

    /**
     * @dev Tells the KYC Providers Manager contract address.
     * @return res the manager address.
     */
    function kycProvidersManager() public view returns (IKycProvidersManager res) {
        assembly {
            res := sload(KYC_PROVIDER_MANAGER_STORAGE)
        }
    }

    /**
     * @dev Updates kyc providers manager contract.
     * Callable only by the contract owner / proxy admin.
     * @param _kycProvidersManager new operator manager implementation.
     */
    function setKycProvidersManager(IKycProvidersManager _kycProvidersManager) external onlyOwner {
        require(Address.isContract(address(_kycProvidersManager)), "KycProvidersManagerStorage: not a contract");
        assembly {
            sstore(KYC_PROVIDER_MANAGER_STORAGE, _kycProvidersManager)
        }
        emit UpdateKYCProvidersManager(address(_kycProvidersManager));
    }
}
