// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ZkBobPool.sol";
import "./ZkBobTokenSellerMixin.sol";
import "./ZkBobPermit2Mixin.sol";

/**
 * @title ZkBobPoolERC20
 * Shielded transactions pool for ERC20 tokens
 */
contract ZkBobPoolERC20 is ZkBobPool, ZkBobTokenSellerMixin, ZkBobPermit2Mixin {
    constructor(
        uint256 __pool_id,
        address _token,
        ITransferVerifier _transfer_verifier,
        ITreeVerifier _tree_verifier,
        IBatchDepositVerifier _batch_deposit_verifier,
        address _direct_deposit_queue,
        address _permit2,
        uint256 _denominator,
        uint256 _precision
    )
        ZkBobPool(
            __pool_id,
            _token,
            _transfer_verifier,
            _tree_verifier,
            _batch_deposit_verifier,
            _direct_deposit_queue,
            _denominator,
            _precision
        )
        ZkBobPermit2Mixin(_permit2)
    {}
}
