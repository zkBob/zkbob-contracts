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
    function _withdrawNative(address _user, uint256 _tokenAmount) internal override returns (uint256) {
        IWETH9(token).withdraw(_tokenAmount);
        if (!payable(_user).send(_tokenAmount)) {
            IWETH9(token).deposit{value: _tokenAmount}();
            IWETH9(token).transfer(_user, _tokenAmount);
        }
        return _tokenAmount;
    }

    // @inheritdoc ZkBobPool
    function _transferFromByPermit(address _user, uint256 _nullifier, int256 _tokenAmount) internal override {
        (uint8 v, bytes32 r, bytes32 s) = _permittable_deposit_signature();

        bytes memory depositSignature = new bytes(65);

        assembly {
            mstore(add(depositSignature, 0x20), r)
            mstore(add(depositSignature, 0x40), s)
            mstore8(add(depositSignature, 0x60), v)
        }

        permit2.permitTransferFrom(
            IPermit2.PermitTransferFrom({
                permitted: IPermit2.TokenPermissions({token: token, amount: uint256(_tokenAmount) * TOKEN_DENOMINATOR}),
                nonce: _nullifier,
                deadline: uint256(_memo_permit_deadline())
            }),
            IPermit2.SignatureTransferDetails({
                to: address(this),
                requestedAmount: uint256(_tokenAmount) * TOKEN_DENOMINATOR
            }),
            _user,
            depositSignature
        );
    }

    receive() external payable {
        require(msg.sender == address(token), "Not a WETH withdrawal");
    }
}
