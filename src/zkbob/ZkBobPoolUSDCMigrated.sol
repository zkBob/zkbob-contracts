// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "./ZkBobPool.sol";
import "./ZkBobTokenSellerMixin.sol";
import "./ZkBobUSDCPermitMixin.sol";

/**
 * @title ZkBobPoolUSDCMigrated
 * Shielded transactions pool for USDC tokens supporting USDC transfer authorizations
 * It is intended to be deployed as implemenation of the pool for BOB tokens that is
 * why it supports the same nomination
 */
contract ZkBobPoolUSDCMigrated is ZkBobPool, ZkBobTokenSellerMixin, ZkBobUSDCPermitMixin {
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

    function migrationToUSDC() external {
        require(msg.sender == address(this), "Incorrect invoker");
        require(token == address(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85), "Incorrect token");

        address bob_addr = address(0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B);
        uint256 cur_bob_balance = IERC20(bob_addr).balanceOf(address(this));
        uint256 bob_decimals = IERC20Metadata(bob_addr).decimals();

        uint256 usdc_decimals = IERC20Metadata(token).decimals();

        ISwapRouter swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        bool retval = IERC20(bob_addr).approve(address(swapRouter), cur_bob_balance);
        uint256 usdc_received = swapRouter.exactInput(
            ISwapRouter.ExactInputParams({
                path: abi.encodePacked(
                    bob_addr, uint24(100), 0x7F5c764cBc14f9669B88837ca1490cCa17c31607, uint24(500), token
                    ),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: cur_bob_balance,
                amountOutMinimum: 0
            })
        );
        require(IERC20(bob_addr).balanceOf(address(this)) == 0, "Incorrect swap");

        uint256 spent_on_fees = (cur_bob_balance / (10 ** (bob_decimals - usdc_decimals))) - usdc_received;

        retval = IERC20(token).transferFrom(owner(), address(this), spent_on_fees);
    }
}
