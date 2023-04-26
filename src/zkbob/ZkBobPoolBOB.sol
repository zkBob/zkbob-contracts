// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ZkBobPool.sol";
import "./ZkBobTokenSellerMixin.sol";
import "./ZkBobSaltedPermitMixin.sol";

/**
 * @title ZkBobPoolBOB
 * Shielded transactions pool for BOB tokens.
 */
contract ZkBobPoolBOB is ZkBobPool, ZkBobTokenSellerMixin, ZkBobSaltedPermitMixin {
    constructor(
        uint256 __pool_id,
        address _token,
        ITransferVerifier _transfer_verifier,
        ITreeVerifier _tree_verifier,
        IBatchDepositVerifier _batch_deposit_verifier,
        address _direct_deposit_queue
    )
        ZkBobPool(__pool_id, _token, _transfer_verifier, _tree_verifier, _batch_deposit_verifier, _direct_deposit_queue)
    {}
}
