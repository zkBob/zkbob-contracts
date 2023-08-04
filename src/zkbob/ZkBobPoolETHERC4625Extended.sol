// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ZkBobPool.sol";
import "./ZkBobERC4626Extended.sol";
import "./ZkBobWETHMixin.sol";
import "./ZkBobPermit2Mixin.sol";

/**
 * @title ZkBobPoolETHERC4625Extended
 * Shielded transactions ERC4626 based pool for native and wrapped native tokens.
 */
contract ZkBobPoolETHERC4625Extended is ZkBobPool, ZkBobERC4626Extended, ZkBobWETHMixin, ZkBobPermit2Mixin {
    constructor(
        uint256 __pool_id,
        address _token,
        ITransferVerifier _transfer_verifier,
        ITreeVerifier _tree_verifier,
        IBatchDepositVerifier _batch_deposit_verifier,
        address _direct_deposit_queue,
        address _permit2
    )
        ZkBobPool(
            __pool_id,
            _token,
            _transfer_verifier,
            _tree_verifier,
            _batch_deposit_verifier,
            _direct_deposit_queue,
            1_000_000_000,
            1_000_000_000
        )
        ZkBobPermit2Mixin(_permit2)
    {}
}
