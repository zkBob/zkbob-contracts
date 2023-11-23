// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../src/interfaces/ITreeVerifier.sol";

contract TreeUpdateVerifierMock is ITreeVerifier {
    bool public result;

    constructor() {
        result = true;
    }

    function setResult(bool _result) external {
        result = _result;
    }
    
    function verifyProof(uint256[3] memory, uint256[8] memory) external view returns (bool) {
        return result;
    }
}
