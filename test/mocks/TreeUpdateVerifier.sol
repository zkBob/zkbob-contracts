//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract TreeUpdateVerifierMock {
    function verifyProof(
        uint256[3] memory,
        uint256[8] memory
    ) external pure returns(bool){
        return true;
    }
}