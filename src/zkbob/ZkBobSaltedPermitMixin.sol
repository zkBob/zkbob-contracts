// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ZkBobPool.sol";

/**
 * @title ZkBobSaltedPermitMixin
 */
abstract contract ZkBobSaltedPermitMixin is ZkBobPool {
    // @inheritdoc ZkBobPool
    function _transferFromByPermit(
        address _user, 
        uint256 _nullifier, 
        int256 _tokenAmount, 
        uint64 _deadline,
        uint8 _v, 
        bytes32 _r, 
        bytes32 _s
    ) internal override {
        IERC20Permit(token).receiveWithSaltedPermit(
            _user,
            uint256(_tokenAmount) * TOKEN_DENOMINATOR / TOKEN_NUMERATOR,
            _deadline,
            bytes32(_nullifier),
            _v,
            _r,
            _s
        );
    }
}
