// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ZkBobPool.sol";

/**
 * @title ZkBobSaltedPermitMixin
 */
abstract contract ZkBobSaltedPermitMixin is ZkBobPool {
    // @inheritdoc ZkBobPool
    function _transferFromByPermit(address _user, uint256 _nullifier, int256 _tokenAmount) internal override {
        (uint8 v, bytes32 r, bytes32 s) = _permittable_deposit_signature();
        IERC20Permit(token).receiveWithSaltedPermit(
            _user,
            uint256(_tokenAmount) * TOKEN_DENOMINATOR / TOKEN_NUMERATOR,
            _memo_permit_deadline(),
            bytes32(_nullifier),
            v,
            r,
            s
        );
    }
}
