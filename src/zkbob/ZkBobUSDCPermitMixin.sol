// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "../interfaces/IUSDCPermit.sol";
import "./ZkBobPool.sol";

/**
 * @title ZkBobUSDCPermitMixin
 */
abstract contract ZkBobUSDCPermitMixin is ZkBobPool {
    // @inheritdoc ZkBobPool
    function _transferFromByPermit(address _user, uint256 _nullifier, int256 _tokenAmount) internal override {
        (uint8 v, bytes32 r, bytes32 s) = _permittable_deposit_signature();
        IUSDCPermit(token).transferWithAuthorization(
            _user,
            address(this),
            uint256(_tokenAmount) * TOKEN_DENOMINATOR,
            0,
            _memo_permit_deadline(),
            bytes32(_nullifier),
            v,
            r,
            s
        );
    }
}
