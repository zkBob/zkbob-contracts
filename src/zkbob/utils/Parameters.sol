// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./CustomABIDecoder.sol";

abstract contract Parameters is CustomABIDecoder {
    uint256 constant R = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    bytes32 constant S_MASK = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256 constant S_MAX = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;
    bytes constant MESSAGE_PREFIX = "\x19Ethereum Signed Message:\n32";

    function _root() internal view virtual returns (uint256);
    function _pool_id() internal view virtual returns (uint256);

    function _transfer_pub() internal view returns (uint256[5] memory r) {
        r[0] = _root();
        r[1] = _transfer_nullifier();
        r[2] = _transfer_out_commit();
        r[3] = _transfer_delta() + (_pool_id() << (transfer_delta_size * 8));
        r[4] = uint256(keccak256(_memo_data())) % R;
    }

    function _tree_pub(uint256 _root_before) internal view returns (uint256[3] memory r) {
        r[0] = _root_before;
        r[1] = _tree_root_after();
        r[2] = _transfer_out_commit();
    }

    // NOTE only valid in the context of normal deposit (tx_type=0)
    function _deposit_spender() internal pure returns (address) {
        (uint8 v, bytes32 r, bytes32 s) = _sign_vrs();
        bytes32 prefixedHash = keccak256(abi.encodePacked(MESSAGE_PREFIX, bytes32(_transfer_nullifier())));
        return ecrecover(prefixedHash, v, r, s);
    }

    // NOTE only valid in the context of permittable token deposit (tx_type=3)
    function _permittable_deposit_signature() internal pure returns (uint8, bytes32, bytes32) {
        return _sign_vrs();
    }

    function _sign_vrs() private pure returns (uint8, bytes32, bytes32) {
        (bytes32 r, bytes32 s) = _sign_r_vs();
        uint8 v = 27 + uint8(uint256(s) >> 255);
        s = s & S_MASK;
        require(uint256(s) <= S_MAX, "ECDSA: invalid signature 's' value");
        return (v, r, s);
    }
}
