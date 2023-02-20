// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

interface IZkBobDirectDepositQueue {
    /**
     * @dev Collects aggregated info about submitted direct deposits and marks them as completed.
     * Callable only by the zkBOB pool contract.
     * @param _indices list of direct deposit indices to process, max of 16 indices are allowed.
     * @param _out_commit pre-calculated out commitment associated with the given deposits.
     * @return total sum of deposit amounts, not counting fees.
     * @return totalFee sum of deposit fees.
     * @return hashsum hashsum over all retrieved direct deposits.
     * @return message memo message to record into the tree.
     */
    function collect(
        uint256[] calldata _indices,
        uint256 _out_commit
    )
        external
        returns (uint256 total, uint256 totalFee, uint256 hashsum, bytes memory message);
}
