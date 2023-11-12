// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./CustomABIDecoder.sol";

abstract contract Parameters is CustomABIDecoder {
    uint256 constant R = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    bytes32 constant S_MASK = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

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
        (bytes32 r, bytes32 vs) = _sign_r_vs();
        return ECDSA.recover(ECDSA.toEthSignedMessageHash(bytes32(_transfer_nullifier())), r, vs);
    }

    // NOTE only valid in the context of permittable token deposit (tx_type=3)
    function _permittable_deposit_signature() internal pure returns (uint8, bytes32, bytes32) {
        (bytes32 r, bytes32 vs) = _sign_r_vs();
        return (uint8((uint256(vs) >> 255) + 27), r, vs & S_MASK);
    }
    function _permittable_signature_proxy_fee() internal view returns (uint8, bytes32, bytes32) {
        (bytes32 r, bytes32 vs) = _sign_r_vs_proxy();
        return (uint8((uint256(vs) >> 255) + 27), r, vs & S_MASK);
    }
}
