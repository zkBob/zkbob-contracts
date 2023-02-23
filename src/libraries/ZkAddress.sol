// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@base58-solidity/Base58.sol";

/**
 * @title ZkAddress
 * Library for parsing zkBob addresses.
 */
library ZkAddress {
    uint256 internal constant R = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    error InvalidZkAddress();
    error InvalidZkAddressLength();
    error InvalidZkAddressChecksum();

    struct ZkAddress {
        bytes10 diversifier;
        bytes32 pk;
    }

    /**
     * @notice Parses zkBob address from the zkBob UI representation.
     * Note that on-chain base58 decoding is quite gas intensive (610k gas),
     * consider to use other gas efficient formats from the below.
     * @param _rawZkAddress zk address base58 string representation in the zkBob UI format.
     * @param _poolId id of the pool to verify checksum for.
     */
    function parseZkAddress(
        string calldata _rawZkAddress,
        uint24 _poolId
    )
        external
        pure
        returns (ZkAddress memory res)
    {
        bytes memory _rawZkAddressBytes = bytes(_rawZkAddress);
        uint256 len = _len(_rawZkAddressBytes);

        if (len > 63 || len < 47) {
            revert InvalidZkAddressLength();
        }

        // _zkAddress == Base58.encode(abi.encodePacked(bytes10(diversifier_le), bytes32(pk_le), bytes4(checksum)))
        bytes memory dec = Base58.decode(_rawZkAddressBytes);
        if (_len(dec) != 46) {
            revert InvalidZkAddressLength();
        }
        res = _parseZkAddressLE46(dec, _poolId);
        if (uint256(res.pk) >= R) {
            revert InvalidZkAddress();
        }
    }

    /**
     * @notice Parses zkBob address from the gas-efficient hex formats.
     * Note difference in endianness among checksummed and non-checksummed formats.
     * @param _rawZkAddress zk address hex representation in one of 3 formats.
     * @param _poolId id of the pool to verify checksum for.
     */
    function parseZkAddress(bytes memory _rawZkAddress, uint24 _poolId) external pure returns (ZkAddress memory res) {
        uint256 len = _len(_rawZkAddress);

        if (len == 42) {
            // _zkAddress == abi.encodePacked(bytes10(diversifier_be), bytes32(pk_be))
            res = ZkAddress(bytes10(_load(_rawZkAddress, 32)), _load(_rawZkAddress, 42));
        } else if (len == 64) {
            // _zkAddress == abi.encode(bytes10(diversifier_be), bytes32(pk_be)) == abi.encode(ZkAddress(zkAddress))
            res = abi.decode(_rawZkAddress, (ZkAddress));
        } else if (len == 46) {
            // _zkAddress == abi.encodePacked(bytes10(diversifier_le), bytes32(pk_le), bytes4(checksum))
            res = _parseZkAddressLE46(_rawZkAddress, _poolId);
        } else if (len < 64 && len > 46) {
            // _zkAddress == Base58.encode(abi.encodePacked(bytes10(diversifier_le), bytes32(pk_le), bytes4(checksum)))
            bytes memory dec = Base58.decode(_rawZkAddress);
            if (_len(dec) != 46) {
                revert InvalidZkAddressLength();
            }
            res = _parseZkAddressLE46(dec, _poolId);
        } else {
            revert InvalidZkAddressLength();
        }
        if (uint256(res.pk) >= R) {
            revert InvalidZkAddress();
        }
    }

    function _parseZkAddressLE46(bytes memory _rawZkAddress, uint24 _poolId) internal pure returns (ZkAddress memory) {
        _verifyChecksum(_poolId, _rawZkAddress);
        bytes32 diversifier = _toLE(_load(_rawZkAddress, 32)) << 176;
        bytes32 pk = _toLE(_load(_rawZkAddress, 42));
        return ZkAddress(bytes10(diversifier), pk);
    }

    function _verifyChecksum(uint24 _poolId, bytes memory _rawZkAddress) internal pure {
        bytes4 checksum = bytes4(_load(_rawZkAddress, 74));
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
            word := mload(add(_b, _offset))
        }
    }

    function _toLE(bytes32 _value) internal pure returns (bytes32 res) {
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
