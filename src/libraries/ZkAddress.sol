// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@base58-solidity/Base58.sol";

library ZkAddress {
    error InvalidZkAddressLength();
    error InvalidZkAddressChecksum();

    struct ZkAddress {
        bytes10 diversifier;
        bytes32 pk;
    }

    function parseZkAddress(bytes memory _rawZkAddress, uint24 _poolId) external pure returns (ZkAddress memory) {
        uint256 len = _len(_rawZkAddress);
        if (len > 64 || (len < 46 && len != 42)) {
            revert InvalidZkAddressLength();
        }

        // _zkAddress == abi.encodePacked(bytes10(diversifier), bytes32(pk))
        if (len == 42) {
            return ZkAddress(bytes10(_load(_rawZkAddress, 0)), _load(_rawZkAddress, 10));
        }

        // _zkAddress == abi.encode(bytes10(diversifier), bytes32(pk))
        if (len == 64) {
            return abi.decode(_rawZkAddress, (ZkAddress));
        }

        // _zkAddress == abi.encodePacked(bytes10(diversifier), bytes32(pk), bytes4(checksum))
        if (len == 46) {
            _verifyChecksum(_poolId, _rawZkAddress);
            return ZkAddress(bytes10(_load(_rawZkAddress, 0)), _load(_rawZkAddress, 10));
        }

        // _zkAddress == Base58.encode(abi.encodePacked(bytes10(diversifier), bytes32(pk), bytes4(checksum)))
        bytes memory dec = Base58.decode(_rawZkAddress);
        if (_len(dec) != 46) {
            revert InvalidZkAddressLength();
        }
        _verifyChecksum(_poolId, dec);
        return ZkAddress(bytes10(_load(dec, 0)), _load(dec, 10));
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
}
