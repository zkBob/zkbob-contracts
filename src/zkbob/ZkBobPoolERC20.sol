// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ZkBobPool.sol";
import "./ZkBobTokenSellerMixin.sol";
import "./ZkBobPermit2Mixin.sol";
import "./ZkBobCompoundingMixin.sol";

/**
 * @title ZkBobPoolERC20
 * Shielded transactions pool for ERC20 tokens
 */
contract ZkBobPoolERC20 is ZkBobPool, ZkBobTokenSellerMixin, ZkBobPermit2Mixin, ZkBobCompoundingMixin {
    constructor(
        uint256 __pool_id,
        address _token,
        ITransferVerifier _transfer_verifier,
        ITreeVerifier _tree_verifier,
        IBatchDepositVerifier _batch_deposit_verifier,
        address _direct_deposit_queue,
        address _permit2,
        uint256 _denominator
    )
        ZkBobPool(
            __pool_id,
            _token,
            _transfer_verifier,
            _tree_verifier,
            _batch_deposit_verifier,
            _direct_deposit_queue,
            _denominator
        )
        ZkBobPermit2Mixin(_permit2)
    {}
}
