// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/zkbob/utils/ZkBobAccounting.sol";
import "../../src/interfaces/ITokenSeller.sol";
import "../../src/interfaces/IOperatorManager.sol";

interface IZkBobPoolAdmin {
    function denominator() external pure returns (uint256);

    function pool_index() external view returns (uint256);

    function initialize(
        uint256 _root,
        uint256 _tvlCap,
        uint256 _dailyDepositCap,
        uint256 _dailyWithdrawalCap,
        uint256 _dailyUserDepositCap,
        uint256 _depositCap,
        uint256 _dailyUserDirectDepositCap,
        uint256 _directDepositCap
    )
        external;

    function setTokenSeller(address _tokenSeller) external;

    function tokenSeller() external returns (ITokenSeller);

    function setOperatorManager(IOperatorManager _operatorManager) external;

    function transact() external;

    function appendDirectDeposits(
        uint256 _root_after,
        uint256[] calldata _indices,
        uint256 _out_commit,
        uint256[8] memory _batch_deposit_proof,
        uint256[8] memory _tree_proof
    )
        external;

    function recordDirectDeposit(address _sender, uint256 _amount) external;

    function withdrawFee(address _operator, address _to) external;

    function setLimits(
        uint8 _tier,
        uint256 _tvlCap,
        uint256 _dailyDepositCap,
        uint256 _dailyWithdrawalCap,
        uint256 _dailyUserDepositCap,
        uint256 _depositCap,
        uint256 _dailyUserDirectDepositCap,
        uint256 _directDepositCap
    )
        external;

    function resetDailyLimits(uint8 _tier) external;

    function setUsersTier(uint8 _tier, address[] memory _users) external;

    function transfer_verifier() external view returns (address);

    function tree_verifier() external view returns (address);

    function batch_deposit_verifier() external view returns (address);

    function operatorManager() external view returns (address);

    function roots(uint256) external view returns (uint256);

    function all_messages_hash() external view returns (bytes32);

    function nullifiers(uint256) external view returns (uint256);

    function accumulatedFee(address) external view returns (uint256);

    function token() external view returns (address);

    function direct_deposit_queue() external view returns (address);

    function pool_id() external view returns (uint256);

    function _root() external view returns (uint256);

    function _pool_id() external view returns (uint256);

    function _withdrawNative(address user, uint256 tokenAmount) external returns (uint256);

    function _transferFromByPermit(address user, uint256 nullifier, int256 tokenAmount) external;

    function _isOwner() external view returns (bool);

    function _txCount() external view returns (uint256);

    function _setLimits(
        uint8 _tier,
        uint256 _tvlCap,
        uint256 _dailyDepositCap,
        uint256 _dailyWithdrawalCap,
        uint256 _dailyUserDepositCap,
        uint256 _depositCap,
        uint256 _dailyUserDirectDepositCap,
        uint256 _directDepositCap
    )
        external;

    function _checkDepositLimits(address _sender, uint256 _amount) external view;

    function _checkWithdrawalLimits(address _receiver, uint256 _amount) external view;

    function _checkDirectDepositLimits(address _sender, uint256 _amount) external view;

    function _setUsersTier(uint8 _tier, address[] memory _users) external;

    function getLimitsFor(address _user) external view returns (ZkBobAccounting.Limits memory);

    function setKycProvidersManager(IKycProvidersManager _kycProvidersManager) external;
}
