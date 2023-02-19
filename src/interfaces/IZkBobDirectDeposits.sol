// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

interface IZkBobDirectDeposits {
    enum DirectDepositStatus {
        Missing, // requested deposit does not exist
        Pending, // requested deposit was submitted and is pending in the queue
        Completed, // requested deposit was successfully processed
        Refunded // requested deposit was refunded to the fallback receiver
    }

    struct DirectDeposit {
        address fallbackReceiver; // refund receiver for deposits that cannot be processed
        uint96 sent; // sent amount in BOB tokens (18 decimals)
        uint64 deposit; // deposit amount, after subtracting all fees (9 decimals)
        uint64 fee; // deposit fee (9 decimals)
        uint40 timestamp; // deposit submission timestamp
        DirectDepositStatus status; // deposit status
        bytes10 diversifier; // receiver zk address, part 1/2
        bytes32 pk; // receiver zk address, part 2/2
    }

    /**
     * @notice Retrieves the direct deposits from the queue by its id.
     * @param depositId id of the submitted deposit.
     * @return deposit recorded deposit struct
     */
    function getDirectDeposit(uint256 depositId) external view returns (DirectDeposit memory deposit);

    /**
     * @notice Performs a direct deposit to the specified zk address.
     * In case the deposit cannot be processed, it can be refunded later to the fallbackReceiver address.
     * @param fallbackReceiver receiver of deposit refund.
     * @param amount direct deposit amount.
     * @param zkAddress receiver zk address.
     * @return depositId id of the submitted deposit to query status for.
     */
    function directDeposit(
        address fallbackReceiver,
        uint256 amount,
        bytes memory zkAddress
    )
        external
        returns (uint256 depositId);

    /**
     * @notice Performs a direct deposit to the specified zk address.
     * In case the deposit cannot be processed, it can be refunded later to the fallbackReceiver address.
     * @param fallbackReceiver receiver of deposit refund.
     * @param amount direct deposit amount.
     * @param zkAddress receiver zk address.
     * @return depositId id of the submitted deposit to query status for.
     */
    function directDeposit(
        address fallbackReceiver,
        uint256 amount,
        string memory zkAddress
    )
        external
        returns (uint256 depositId);

    /**
     * @notice ERC677 callback for performing a direct deposit.
     * Do not call this function directly, it's only intended to be called by the token contract.
     * @param from original tokens sender.
     * @param amount direct deposit amount.
     * @param data encoded address pair - abi.encode(address(fallbackReceiver), bytes(zkAddress))
     * @return ok true, if deposit of submitted successfully.
     */
    function onTokenTransfer(address from, uint256 amount, bytes memory data) external returns (bool ok);

    /**
     * @notice Tells the direct deposit fee, in zkBOB units (9 decimals).
     * @return fee direct deposit submission fee.
     */
    function directDepositFee() external view returns (uint64 fee);

    /**
     * @notice Tells the timeout after which unprocessed direct deposits can be refunded.
     * @return timeout duration in seconds.
     */
    function directDepositTimeout() external view returns (uint40 timeout);

    /**
     * @notice Tells the nonce of next direct deposit.
     * @return nonce direct deposit nonce.
     */
    function directDepositNonce() external view returns (uint32 nonce);

    /**
     * @notice Refunds specified direct deposit.
     * Can be called by anyone, but only after the configured timeout has passed.
     * Function will revert for deposit that is not pending.
     * @param index deposit id to issue a refund for.
     */
    function refundDirectDeposit(uint256 index) external;

    /**
     * @notice Refunds multiple direct deposits.
     * Can be called by anyone, but only after the configured timeout has passed.
     * Function will do nothing for non-pending deposits and will not revert.
     * @param indices deposit ids to issue a refund for.
     */
    function refundDirectDeposit(uint256[] memory indices) external;
}
