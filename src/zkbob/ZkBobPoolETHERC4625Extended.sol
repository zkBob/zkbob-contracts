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
contract ZkBobPoolETHERC4625Extended is ZkBobPool, ZkBobWETHMixin, ZkBobERC4626Extended, ZkBobPermit2Mixin {
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

    function checkOnReceivingETH() internal override {
        require(msg.sender == IATokenVault(token).UNDERLYING(), "Not a WETH withdrawal");
    }

    // There is no need in this method if a new pool is deployed
    function migrationToERC4626() external {
        require(msg.sender == address(this), "Incorrect invoker");
        require(token == address(0x4A2207534B019303C6cd856989Ec272F9FD3B654), "Incorrect token");

        address weth = address(IATokenVault(token).UNDERLYING());
        uint256 cur_weth_balance = IERC20(weth).balanceOf(address(this));

        IERC20(weth).approve(token, cur_weth_balance);
        uint256 shares = IATokenVault(token).deposit(cur_weth_balance, address(this));

        require(IERC20(weth).balanceOf(address(this)) == 0, "Incorrect swap");
        require(IERC20(token).balanceOf(address(this)) == shares, "Incorrect amount of received shares");
    }
}
