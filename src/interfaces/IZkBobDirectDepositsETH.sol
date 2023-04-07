// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

import "./IZkBobDirectDeposits.sol";

interface IZkBobDirectDepositsETH is IZkBobDirectDeposits {
    /**
     * @notice Performs a direct deposit to the specified zk address in native token.
     * In case the deposit cannot be processed, it can be refunded later to the fallbackReceiver address.
     * @param fallbackReceiver receiver of deposit refund.
     * @param zkAddress receiver zk address.
     * @return depositId id of the submitted deposit to query status for.
     */
    function directNativeDeposit(
        address fallbackReceiver,
        bytes memory zkAddress
    )
        external
        payable
        returns (uint256 depositId);

    /**
     * @notice Performs a direct deposit to the specified zk address in native token.
     * In case the deposit cannot be processed, it can be refunded later to the fallbackReceiver address.
     * @param fallbackReceiver receiver of deposit refund.
     * @param zkAddress receiver zk address.
     * @return depositId id of the submitted deposit to query status for.
     */
    function directNativeDeposit(
        address fallbackReceiver,
        string memory zkAddress
    )
        external
        payable
        returns (uint256 depositId);
}
