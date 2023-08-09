// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "../interfaces/IPermit2.sol";
import "./ZkBobPool.sol";

/**
 * @title ZkBobPermit2Mixin
 */
abstract contract ZkBobPermit2Mixin is ZkBobPool {
    IPermit2 public immutable permit2;

    constructor(address _permit2) {
        require(Address.isContract(_permit2), "ZkBobPool: not a contract");
        permit2 = IPermit2(_permit2);
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
                permitted: IPermit2.TokenPermissions({
                    token: token,
                    amount: uint256(_tokenAmount) * TOKEN_DENOMINATOR / TOKEN_NUMERATOR
                }),
                nonce: _nullifier,
                deadline: uint256(_memo_permit_deadline())
            }),
            IPermit2.SignatureTransferDetails({
                to: address(this),
                requestedAmount: uint256(_tokenAmount) * TOKEN_DENOMINATOR / TOKEN_NUMERATOR
            }),
            _user,
            depositSignature
        );
    }
}
