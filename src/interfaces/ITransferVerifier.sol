//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ITransferVerifier {
    function verifyProof(
        uint256[5] memory input,
        uint256[8] memory p
    ) external view returns (bool);
}
