// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

// New memo struct
// 0-2 bytes - tx type?
// 2-22 bytes - proxy address
// 22-54 bytes - proxy fee
// 54-86 bytes - prover fee

library MemoUtils {
    function parseFees(bytes memory memo) public pure returns (address proxyAddress, uint256 proxyFee, uint256 proverFee) {
        // TODO
    }

    function parseTokenDelta(uint256 transferDelta) public pure returns (int64) {
        return int64(uint64(transferDelta >> 192));
    }

    function parseTxType(bytes memory memo) public pure returns (uint16) {
        // TODO
    }

    function parseMessagePrefix(bytes memory memo) public pure returns (bytes4) {
        // TODO
    }
}