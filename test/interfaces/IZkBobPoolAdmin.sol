// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/zkbob/utils/ZkBobAccounting.sol";
import "../../src/interfaces/ITokenSeller.sol";
import "../../src/interfaces/IOperatorManager.sol";
import "../../src/interfaces/IEnergyRedeemer.sol";

interface IZkBobPoolAdmin {
    function denominator() external pure returns (uint256);

    function pool_index() external view returns (uint256);

    function pendingCommitment() external view returns (uint256, address, uint64, uint64);

    function initialize(uint256 _root) external;

    function setTokenSeller(address _tokenSeller) external;

    function tokenSeller() external returns (ITokenSeller);

    function setOperatorManager(IOperatorManager _operatorManager) external;

    function setAccounting(IZkBobAccounting _accounting) external;

    function setEnergyRedeemer(IEnergyRedeemer _redeemer) external;

    function setGracePeriod(uint64 _gracePeriod) external;

    function setMinTreeUpdateFee(uint64 _minTreeUpdateFee) external;

    function accounting() external view returns (address);

    function transact() external;

    function proveTreeUpdate(uint256, uint256[8] memory, uint256) external;

    function committedForcedExits(uint256 _nullifier) external view returns (bytes32);

    function commitForcedExit(
        address _operator,
        address _to,
        uint256 _amount,
        uint256 _index,
        uint256 _nullifier,
        uint256 _out_commit,
        uint256[8] memory _transfer_proof
    )
        external;

    function executeForcedExit(
        uint256 _nullifier,
        address _operator,
        address _to,
        uint256 _amount,
        uint256 _exitStart,
        uint256 _exitEnd,
        bool _cancel
    )
        external;

    function appendDirectDeposits(
        uint256[] calldata _indices,
        uint256 _out_commit,
        uint256[8] memory _batch_deposit_proof
    )
        external;

    function recordDirectDeposit(address _sender, uint256 _amount) external;

    function withdrawFee(address _operator, address _to) external;

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

    function gracePeriod() external view returns (uint64);
}
