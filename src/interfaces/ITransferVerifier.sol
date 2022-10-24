// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

interface ITransferVerifier {
    function verifyProof(uint256[9] memory input, uint256[8] memory p) external view returns (bool);
}
