// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

// New memo struct
// 0-2 bytes - tx type?
// 2-22 bytes - proxy address
// 22-30 bytes - proxy fee
// 30-38 bytes - prover fee
import "../utils/CustomABIDecoder.sol";
import "forge-std/console2.sol";

contract MemoUtils is CustomABIDecoder{
    function parseFees(bytes memory memo) public pure returns (address proxyAddress, uint64 proxyFee, uint64 proverFee) {
        assembly {
            proxyAddress := mload(add(memo, 0x14)) // 32 - 12 = 20
            proxyFee := mload(add(memo, 0x1c)) // 32 + 20 - 24 = 28
            proverFee := mload(add(memo, 0x24)) // 32 + 20 + 8 - 24 = 36
        }
    }

    function parseMessagePrefix(bytes memory memo, uint16 txType) public pure returns (bytes4 prefix) {
        uint256 offset = _memo_fixed_size(txType) + 32;
        assembly {
            prefix := mload(add(memo, offset))
        }
        prefix = prefix & 0x0000ffff;
    }

    function _parsePermitData(bytes memory memo) internal pure returns (uint64 expiry, address holder) {

        uint256 offset; 
        assembly {
            offset := add(memo, 0x20)
            expiry := mload(add(offset, 0xc)) //  36 - 32 + 8 = 12
            holder := mload(add(offset, 0x20)) // 44-32+20 = 42
        }
    }

    function _memo_fixed_size(uint16 txType) internal pure returns (uint256 r) {
        if (txType == 0 || txType == 1) {
            // prover + proxy fee + prover fee
            // 20 + 8 + 8 = 36
            r = 36;
        } else if (txType == 2) {
            // prover + proxy fee + prover fee + native amount + recipient
            // 36 + 8 + 20
            r = 64;
        } else if (txType == 3) {
            // prover + proxy fee + prover fee + deadline + address
            // 36 + 8 + 20
            r = 64;
        } else {
            revert();
        }
    }
}