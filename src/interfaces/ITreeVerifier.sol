// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

interface ITreeVerifier {
    function verifyProof(uint256[3] memory input, uint256[8] memory p) external view returns (bool);
}
