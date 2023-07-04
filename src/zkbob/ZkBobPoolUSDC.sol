// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ZkBobPool.sol";
import "./ZkBobTokenSellerMixin.sol";
import "./ZkBobUSDCPermitMixin.sol";

/**
 * @title ZkBobPoolUSDC
 * Shielded transactions pool for USDC tokens supporting USDC transfer authorizations
 */
contract ZkBobPoolUSDC is ZkBobPool, ZkBobTokenSellerMixin, ZkBobUSDCPermitMixin {
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
            1,
            1_000_000_000
        )
    {}

    function migrationToUSDC() external {
        require(msg.sender == address(this), "Incorrect invoker");
        require(token == address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174), "Incorrect token");

        address bob_addr = address(0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B);
        uint256 cur_bob_balance = IERC20(bob_addr).balanceOf(address(this));
        uint256 bob_decimals = IERC20Metadata(bob_addr).decimals();

        // uint256 prev_usdc_balance = IERC20(token).balanceOf(address(this));
        uint256 usdc_decimals = IERC20Metadata(token).decimals();

        IBobVault bobswap = IBobVault(0x25E6505297b44f4817538fB2d91b88e1cF841B54);
        bool retval = IERC20(bob_addr).approve(address(bobswap), cur_bob_balance);
        uint256 usdc_received = bobswap.sell(token, cur_bob_balance);
        require(IERC20(bob_addr).balanceOf(address(this)) == 0, "Incorrect swap");

        // uint256 usdc_received = IERC20(token).balanceOf(address(this)) - prev_usdc_balance;
        uint256 spent_on_fees = (cur_bob_balance / (10 ** (bob_decimals - usdc_decimals))) - usdc_received;

        retval = IERC20(token).transferFrom(owner(), address(this), spent_on_fees);
    }
}
