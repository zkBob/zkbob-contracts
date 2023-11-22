// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "../interfaces/IUSDCPermit.sol";
import "./ZkBobPool.sol";

/**
 * @title ZkBobUSDCPermitMixin
 */
abstract contract ZkBobUSDCPermitMixin is ZkBobPool {
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
        IUSDCPermit(token).transferWithAuthorization(
            _user,
            address(this),
            uint256(_tokenAmount) * TOKEN_DENOMINATOR / TOKEN_NUMERATOR,
            0,
            _deadline,
            bytes32(_nullifier),
            _v,
            _r,
            _s
        );
    }
}
