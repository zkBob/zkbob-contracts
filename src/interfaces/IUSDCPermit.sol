// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

interface IUSDCPermit {
    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external;
}
