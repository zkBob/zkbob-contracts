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
            proxyAddress := mload(add(memo, 0x14)) // 32 - 12 = 20
            proxyFee := mload(add(memo, 0x1c)) // 32 + 20 - 24 = 28
            proverFee := mload(add(memo, 0x24)) // 32 + 20 + 8 - 24 = 36
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