// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ZkBobPool.sol";
import "./ZkBobDTO.sol";
import "./ZkBobTokenSellerMixin.sol";
import "./ZkBobUSDCPermitMixin.sol";

/**
 * @title ZkBobPoolUSDCMigrated
 * Shielded transactions pool for USDC tokens supporting USDC transfer authorizations
 * It is intended to be deployed as implemenation of the pool for BOB tokens that is
 * why it supports the same nomination
 */
contract ZkBobPoolUSDCMigrated is ZkBobPool, ZkBobDTO, ZkBobTokenSellerMixin, ZkBobUSDCPermitMixin {
    constructor(
        uint256 __pool_id,
        address _token,
        ITransferVerifier _transfer_verifier,
        ITreeVerifier _tree_verifier,
        IBatchDepositVerifier _batch_deposit_verifier,
        address _direct_deposit_queue
    )
        ZkBobPool(
            __pool_id,
            _token,
            _transfer_verifier,
            _tree_verifier,
            _batch_deposit_verifier,
            _direct_deposit_queue,
            1, // Make sure that TOKEN_NUMERATOR is set in 1000 in ZkBobPool and ZkBobDirectDepositQueue
            1_000_000_000
        )
    {}
}
