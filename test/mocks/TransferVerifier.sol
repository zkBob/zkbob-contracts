//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract TransferVerifierMock {
    function verifyProof(
        uint256[5] memory,
        uint256[8] memory
    ) external pure returns (bool) {
        return true;
    }
}
