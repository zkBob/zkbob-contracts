// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {Parameters} from "../utils/Parameters.sol";

abstract contract SequencerABIDecoder is Parameters {
    function _parseCommitData() internal pure returns (
        uint256 nullifier,
        uint256 outCommit,
        uint48 transferIndex,
        uint256 transferDelta,
        int64 tokenAmount,
        uint256[8] calldata transferProof,
        uint16 txType,
        bytes calldata memo
    ) {
        nullifier = _transfer_nullifier();
        outCommit = _transfer_out_commit();
        transferIndex = _transfer_index();
        transferDelta = _transfer_delta();
        tokenAmount = _transfer_token_amount();
        transferProof = _transfer_proof();

        uint256 offset = tree_root_after_pos;
        txType = uint16(_loaduint256(offset + tx_type_size - uint256_size) & tx_type_mask);
        
        offset = offset + tx_type_size;
        uint256 memoLength = _loaduint256(offset + memo_data_size_size - uint256_size) & memo_data_size_mask;
        
        
        offset = offset + memo_data_size_size;
        assembly {
            memo.offset := offset
            memo.length := memoLength
        }
    }

    function _sign_r_vs_proxy() internal pure returns (bytes32 r, bytes32 vs) {
        uint256 offset = tree_root_after_pos + tx_type_size;
        uint256 memoLength = _loaduint256(offset + memo_data_size_size - uint256_size) & memo_data_size_mask;
        offset = offset + memo_data_size_size + memoLength + sign_r_vs_size;
        assembly {
            r := calldataload(offset)
            vs := calldataload(add(offset, 32))
        }
    }

    function _permittable_signature_proxy_fee() internal pure returns (uint8, bytes32, bytes32) {
        (bytes32 r, bytes32 vs) = _sign_r_vs_proxy();
        return (uint8((uint256(vs) >> 255) + 27), r, vs & S_MASK);
    }
}