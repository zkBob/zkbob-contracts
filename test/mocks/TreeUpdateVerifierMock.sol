// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../src/interfaces/ITreeVerifier.sol";

contract TreeUpdateVerifierMock is ITreeVerifier {
    function verifyProof(uint256[3] memory, uint256[8] memory) external pure returns (bool) {
        return true;
    }
}
