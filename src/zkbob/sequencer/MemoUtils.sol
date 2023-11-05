// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

// New memo struct
// 0-2 bytes - tx type?
// 2-22 bytes - proxy address
// 22-30 bytes - proxy fee
// 30-38 bytes - prover fee
import "../utils/CustomABIDecoder.sol";


contract MemoUtils is CustomABIDecoder{
    function parseFees(bytes memory memo) public pure returns (address proxyAddress, uint64 proxyFee, uint64 proverFee) {
        assembly {
            proxyAddress := mload(add(memo, 0x16)) // 32 + 2 - 12 = 22
            proxyFee := mload(add(memo, 0x1e)) // 32 + 2 + 20 - 24 = 30
            proverFee := mload(add(memo, 0x26)) // 32 + 2 + 20 + 8 - 24 = 38
        }
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