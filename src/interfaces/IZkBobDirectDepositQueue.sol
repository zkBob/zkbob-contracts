// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

interface IZkBobDirectDepositQueue {
    function collect(
        uint256[] calldata _indices,
        uint256 _out_commit
    )
        external
        returns (uint256 total, uint256 totalFee, uint256 hashsum, bytes memory message);
}
