// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../src/interfaces/ITransferVerifier.sol";

contract TransferVerifierMock is ITransferVerifier {
    function verifyProof(uint256[5] memory, uint256[8] memory) external pure returns (bool) {
        return true;
    }
}
