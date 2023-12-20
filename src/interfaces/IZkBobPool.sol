// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

import "./IZkBobAccounting.sol";

interface IZkBobPool {
    function pool_id() external view returns (uint256);

    function denominator() external view returns (uint256);

    function accounting() external view returns (IZkBobAccounting);

    function recordDirectDeposit(address _sender, uint256 _amount) external;

    function appendDirectDeposits(
        uint256 _root_after,
        uint256[] calldata _indices,
        uint256 _out_commit,
        uint256[8] memory _batch_deposit_proof,
        uint256[8] memory _tree_proof
    )
        external;
}
