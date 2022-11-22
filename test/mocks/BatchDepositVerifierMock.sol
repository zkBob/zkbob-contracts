// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../src/interfaces/IBatchDepositVerifier.sol";

contract BatchDepositVerifierMock is IBatchDepositVerifier {
    function verifyProof(uint256[33] memory, uint256[8] memory) external pure returns (bool) {
        return true;
    }
}
