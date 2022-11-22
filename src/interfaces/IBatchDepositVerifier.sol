// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

interface IBatchDepositVerifier {
    function verifyProof(uint256[33] memory input, uint256[8] memory p) external view returns (bool);
}
