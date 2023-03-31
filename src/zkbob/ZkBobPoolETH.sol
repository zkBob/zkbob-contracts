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
import "../interfaces/IPermit2.sol";
import "../interfaces/IZkBobDirectDepositQueue.sol";
import "../interfaces/IZkBobPool.sol";
import "./utils/Parameters.sol";
import "./utils/ZkBobAccounting.sol";
import "../utils/Ownable.sol";
import "../proxy/EIP1967Admin.sol";
import "../utils/Sacrifice.sol";
import "./ZkBobPool.sol";

/**
 * @title ZkBobETHPool
 * Shielded transactions pool for native and wrappred native tokens.
 */
contract ZkBobPoolETH is ZkBobPool {
    using SafeERC20 for IERC20;

    IPermit2 public immutable permit2;

    constructor(
        uint256 __pool_id,
        address _token,
        ITransferVerifier _transfer_verifier,
        ITreeVerifier _tree_verifier,
        IBatchDepositVerifier _batch_deposit_verifier,
        address _direct_deposit_queue,
        address _permit2
    )
        ZkBobPool(__pool_id, _token, _transfer_verifier, _tree_verifier, _batch_deposit_verifier, _direct_deposit_queue)
    {
        require(Address.isContract(_permit2), "ZkBobPool: not a contract");
        permit2 = IPermit2(_permit2);
    }

    // @inheritdoc ZkBobPool
    function _withdrawNative(address user, uint256 tokenAmount) internal override returns (uint256 spentAmount) {
        IWETH9(token).withdraw(tokenAmount);
        if (!payable(user).send(tokenAmount)) {
            new Sacrifice{value: tokenAmount}(user);
        }
        return tokenAmount;
    }

    // @inheritdoc ZkBobPool
    function _finalizePermitDeposit(address user, uint256 nullifier, int256 tokenAmount) internal override {
        (uint8 v, bytes32 r, bytes32 s) = _permittable_deposit_signature();

        bytes memory depositSignature = new bytes(65);

        assembly {
            mstore(add(depositSignature, 0x20), r)
            mstore(add(depositSignature, 0x40), s)
            mstore8(add(depositSignature, 0x60), v)
        }

        permit2.permitTransferFrom(
            IPermit2.PermitTransferFrom({
                permitted: IPermit2.TokenPermissions({token: token, amount: uint256(tokenAmount) * TOKEN_DENOMINATOR}),
                nonce: nullifier,
                deadline: uint256(_memo_permit_deadline())
            }),
            IPermit2.SignatureTransferDetails({
                to: address(this),
                requestedAmount: uint256(tokenAmount) * TOKEN_DENOMINATOR
            }),
            user,
            depositSignature
        );
    }

    //    /**
    //     * @dev Perform a zkBob pool transaction.
    //     * Callable only by the current operator.
    //     * Method uses a custom ABI encoding scheme described in CustomABIDecoder.
    //     * Single transact() call performs either deposit, withdrawal or shielded transfer operation.
    //     */
    //    function transact() external onlyOperator {
    //        address user;
    //        uint256 txType = _tx_type();
    //        if (txType == 0) {
    //            user = _deposit_spender();
    //        } else if (txType == 2) {
    //            user = _memo_receiver();
    //        } else if (txType == 3) {
    //            user = _memo_permit_holder();
    //        }
    //        int256 transfer_token_delta = _transfer_token_amount();
    //        (,, uint256 txCount) = _recordOperation(user, transfer_token_delta);
    //
    //        uint256 nullifier = _transfer_nullifier();
    //        {
    //            uint256 _pool_index = txCount << 7;
    //
    //            require(nullifiers[nullifier] == 0, "ZkBobPool: doublespend detected");
    //            require(_transfer_index() <= _pool_index, "ZkBobPool: transfer index out of bounds");
    //            require(transfer_verifier.verifyProof(_transfer_pub(), _transfer_proof()), "ZkBobPool: bad transfer proof");
    //            require(
    //                tree_verifier.verifyProof(_tree_pub(roots[_pool_index]), _tree_proof()), "ZkBobPool: bad tree proof"
    //            );
    //
    //            nullifiers[nullifier] = uint256(keccak256(abi.encodePacked(_transfer_out_commit(), _transfer_delta())));
    //            _pool_index += 128;
    //            roots[_pool_index] = _tree_root_after();
    //            bytes memory message = _memo_message();
    //            // restrict memo message prefix (items count in little endian) to be < 2**16
    //            require(bytes4(message) & 0x0000ffff == MESSAGE_PREFIX_COMMON_V1, "ZkBobPool: bad message prefix");
    //            bytes32 message_hash = keccak256(message);
    //            bytes32 _all_messages_hash = keccak256(abi.encodePacked(all_messages_hash, message_hash));
    //            all_messages_hash = _all_messages_hash;
    //            emit Message(_pool_index, _all_messages_hash, message);
    //        }
    //
    //        uint256 fee = _memo_fee();
    //        int256 token_amount = transfer_token_delta + int256(fee);
    //        int256 energy_amount = _transfer_energy_amount();
    //
    //        if (txType == 0) {
    //            // Deposit
    //            require(transfer_token_delta > 0 && energy_amount == 0, "ZkBobPool: incorrect deposit amounts");
    //            IERC20(token).safeTransferFrom(user, address(this), uint256(token_amount) * TOKEN_DENOMINATOR);
    //        } else if (txType == 1) {
    //            // Transfer
    //            require(token_amount == 0 && energy_amount == 0, "ZkBobPool: incorrect transfer amounts");
    //        } else if (txType == 2) {
    //            // Withdraw
    //            require(token_amount <= 0 && energy_amount <= 0, "ZkBobPool: incorrect withdraw amounts");
    //
    //            uint256 native_amount = _memo_native_amount() * TOKEN_DENOMINATOR;
    //            uint256 withdraw_amount = uint256(-token_amount) * TOKEN_DENOMINATOR;
    //
    //            if (native_amount > 0) {
    //                token.withdraw(native_amount);
    //                if (!payable(user).send(native_amount)) {
    //                    new Sacrifice{value: native_amount}(user);
    //                }
    //                withdraw_amount = withdraw_amount - native_amount;
    //            }
    //
    //            if (withdraw_amount > 0) {
    //                IERC20(token).safeTransfer(user, withdraw_amount);
    //            }
    //
    //            // energy withdrawals are not yet implemented, any transaction with non-zero energy_amount will revert
    //            // future version of the protocol will support energy withdrawals through negative energy_amount
    //            if (energy_amount < 0) {
    //                revert("ZkBobPool: XP claiming is not yet enabled");
    //            }
    //        } else if (txType == 3) {
    //            // Permittable token deposit
    //            require(transfer_token_delta > 0 && energy_amount == 0, "ZkBobPool: incorrect deposit amounts");
    //            (uint8 v, bytes32 r, bytes32 s) = _permittable_deposit_signature();
    //
    //            bytes memory depositSignature = new bytes(65);
    //
    //            assembly {
    //                mstore(add(depositSignature, 0x20), r)
    //                mstore(add(depositSignature, 0x40), s)
    //                mstore8(add(depositSignature, 0x60), v)
    //            }
    //
    //            permit2.permitTransferFrom(
    //                IPermit2.PermitTransferFrom({
    //                    permitted: IPermit2.TokenPermissions({
    //                        token: address(token),
    //                        amount: uint256(token_amount) * TOKEN_DENOMINATOR
    //                    }),
    //                    nonce: nullifier,
    //                    deadline: uint256(_memo_permit_deadline())
    //                }),
    //                IPermit2.SignatureTransferDetails({
    //                    to: address(this),
    //                    requestedAmount: uint256(token_amount) * TOKEN_DENOMINATOR
    //                }),
    //                user,
    //                depositSignature
    //            );
    //        } else {
    //            revert("ZkBobPool: Incorrect transaction type");
    //        }
    //
    //        if (fee > 0) {
    //            accumulatedFee[msg.sender] += fee;
    //        }
    //    }

    receive() external payable {
        require(msg.sender == address(token), "Not a WETH withdrawal");
    }
}
