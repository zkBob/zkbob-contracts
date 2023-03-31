// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol";
import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "../interfaces/ITransferVerifier.sol";
import "../interfaces/ITreeVerifier.sol";
import "../interfaces/IBatchDepositVerifier.sol";
import "../interfaces/IMintableERC20.sol";
import "../interfaces/IOperatorManager.sol";
import "../interfaces/IERC20Permit.sol";
import "../interfaces/ITokenSeller.sol";
import "../interfaces/IZkBobDirectDepositQueue.sol";
import "../interfaces/IZkBobPool.sol";
import "./utils/Parameters.sol";
import "./utils/ZkBobAccounting.sol";
import "../utils/Ownable.sol";
import "../proxy/EIP1967Admin.sol";
import "./ZkBobPool.sol";

/**
 * @title ZkBobPool
 * Shielded transactions pool for BOB tokens.
 */
contract ZkBobPoolERC20 is ZkBobPool {
    using SafeERC20 for IERC20;

    ITokenSeller public tokenSeller;

    event UpdateTokenSeller(address seller);

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

    /**
     * @dev Updates token seller contract used for native coin withdrawals.
     * Callable only by the contract owner / proxy admin.
     * @param _seller new token seller contract implementation. address(0) will deactivate native withdrawals.
     */
    function setTokenSeller(address _seller) external onlyOwner {
        tokenSeller = ITokenSeller(_seller);
        emit UpdateTokenSeller(_seller);
    }

    // @inheritdoc ZkBobPool
    function _withdrawNative(address user, uint256 tokenAmount) internal override returns (uint256 spentAmount) {
        ITokenSeller seller = tokenSeller;
        if (address(seller) != address(0)) {
            IERC20(token).safeTransfer(address(seller), tokenAmount);
            (, uint256 refunded) = seller.sellForETH(user, tokenAmount);
            return tokenAmount - refunded;
        }
    }

    // @inheritdoc ZkBobPool
    function _finalizePermitDeposit(address user, uint256 nullifier, int256 tokenAmount) internal override {
        (uint8 v, bytes32 r, bytes32 s) = _permittable_deposit_signature();
        IERC20Permit(token).receiveWithSaltedPermit(
            user, uint256(tokenAmount) * TOKEN_DENOMINATOR, _memo_permit_deadline(), bytes32(nullifier), v, r, s
        );
    }
}
