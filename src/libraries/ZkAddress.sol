// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@base58-solidity/Base58.sol";

library ZkAddress {
    uint256 internal constant R = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    error InvalidZkAddress();
    error InvalidZkAddressLength();
    error InvalidZkAddressChecksum();

    struct ZkAddress {
        bytes10 diversifier;
        bytes32 pk;
    }

    function parseZkAddress(bytes memory _rawZkAddress, uint24 _poolId) external pure returns (ZkAddress memory res) {
        uint256 len = _len(_rawZkAddress);
        if (len > 64 || (len < 46 && len != 42)) {
            revert InvalidZkAddressLength();
        }

        if (len == 42) {
            // _zkAddress == abi.encodePacked(bytes10(diversifier), bytes32(pk))
            res = ZkAddress(bytes10(_load(_rawZkAddress, 0)), _load(_rawZkAddress, 10));
        } else if (len == 64) {
            // _zkAddress == abi.encode(bytes10(diversifier), bytes32(pk))
            res = abi.decode(_rawZkAddress, (ZkAddress));
        } else if (len == 46) {
            // _zkAddress == abi.encodePacked(bytes10(diversifier), bytes32(pk), bytes4(checksum))
            _verifyChecksum(_poolId, _rawZkAddress);
            res = ZkAddress(bytes10(_load(_rawZkAddress, 0)), _load(_rawZkAddress, 10));
        } else {
            // _zkAddress == Base58.encode(abi.encodePacked(bytes10(diversifier), bytes32(pk), bytes4(checksum)))
            bytes memory dec = Base58.decode(_rawZkAddress);
            if (_len(dec) != 46) {
                revert InvalidZkAddressLength();
            }
            _verifyChecksum(_poolId, dec);
            res = ZkAddress(bytes10(_load(dec, 0)), _load(dec, 10));
        }
        if (_toLE(uint256(res.pk)) >= R) {
            revert InvalidZkAddress();
        }
    }

    function _verifyChecksum(uint24 _poolId, bytes memory _rawZkAddress) internal pure {
        bytes4 checksum = bytes4(_load(_rawZkAddress, 42));
        bytes32 zkAddressHash;
        assembly {
            zkAddressHash := keccak256(add(_rawZkAddress, 32), 42)
        }
        bytes4 zkAddressChecksum1 = bytes4(zkAddressHash);
        bytes4 zkAddressChecksum2 = bytes4(keccak256(abi.encodePacked(_poolId, zkAddressHash)));
        if (checksum != zkAddressChecksum1 && checksum != zkAddressChecksum2) {
            revert InvalidZkAddressChecksum();
        }
    }

    function _len(bytes memory _b) internal pure returns (uint256 len) {
        assembly {
            len := mload(_b)
        }
    }

    function _load(bytes memory _b, uint256 _offset) internal pure returns (bytes32 word) {
        assembly {
            word := mload(add(_b, add(32, _offset)))
        }
    }

    function _toLE(uint256 _value) internal pure returns (uint256 res) {
        assembly {
            res := byte(0, _value)
            res := add(res, shl(8, byte(1, _value)))
            res := add(res, shl(16, byte(2, _value)))
            res := add(res, shl(24, byte(3, _value)))
            res := add(res, shl(32, byte(4, _value)))
            res := add(res, shl(40, byte(5, _value)))
            res := add(res, shl(48, byte(6, _value)))
            res := add(res, shl(56, byte(7, _value)))
            res := add(res, shl(64, byte(8, _value)))
            res := add(res, shl(72, byte(9, _value)))
            res := add(res, shl(80, byte(10, _value)))
            res := add(res, shl(88, byte(11, _value)))
            res := add(res, shl(96, byte(12, _value)))
            res := add(res, shl(104, byte(13, _value)))
            res := add(res, shl(112, byte(14, _value)))
            res := add(res, shl(120, byte(15, _value)))
            res := add(res, shl(128, byte(16, _value)))
            res := add(res, shl(136, byte(17, _value)))
            res := add(res, shl(144, byte(18, _value)))
            res := add(res, shl(152, byte(19, _value)))
            res := add(res, shl(160, byte(20, _value)))
            res := add(res, shl(168, byte(21, _value)))
            res := add(res, shl(176, byte(22, _value)))
            res := add(res, shl(184, byte(23, _value)))
            res := add(res, shl(192, byte(24, _value)))
            res := add(res, shl(200, byte(25, _value)))
            res := add(res, shl(208, byte(26, _value)))
            res := add(res, shl(216, byte(27, _value)))
            res := add(res, shl(224, byte(28, _value)))
            res := add(res, shl(232, byte(29, _value)))
            res := add(res, shl(240, byte(30, _value)))
            res := add(res, shl(248, byte(31, _value)))
        }
    }
}
