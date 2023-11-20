// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {Parameters} from "../utils/Parameters.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

abstract contract SequencerABIDecoder is Parameters {
    function _parseCommitCalldata() internal pure returns (
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

        // TODO: add comment
        uint256 tx_type_pos = tree_root_after_pos;
        txType = uint16(_loaduint256(tx_type_pos + tx_type_size - uint256_size) & tx_type_mask);
        
        (uint256 memoPos, uint256 memoSize) = _commit_memo_pos_and_size();
        assembly {
            memo.offset := memoPos
            memo.length := memoSize
        }
    }

    function _commit_memo_pos_and_size() private pure returns (uint256 pos, uint256 size) {
        pos = tree_root_after_pos + tx_type_size;
        size = _loaduint256(pos + memo_data_size_size - uint256_size) & memo_data_size_mask;
        pos = pos + memo_data_size_size;
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

    function _parseProverAndFees(bytes calldata memo) internal pure returns (address proxyAddress, uint64 proxyFee, uint64 proverFee) {
        uint256 offset;
        assembly {
            offset := memo.offset
        }
        
        proxyAddress = address(uint160(_loaduint256(offset + memo_proxy_address_size - uint256_size)));
        offset = offset + memo_proxy_address_size;

        proxyFee = uint64(_loaduint256(offset + memo_proxy_fee_size - uint256_size));
        offset = offset + memo_proxy_fee_size;
        
        proverFee = uint64(_loaduint256(offset + memo_prover_fee_size - uint256_size));
    }

    function _parseMessagePrefix(bytes calldata memo, uint16 txType) internal pure returns (bytes4 prefix) {
        uint256 offset = _memo_fixed_size(txType);
        assembly {
            prefix := calldataload(add(memo.offset, offset))
        }
        prefix = prefix & 0x0000ffff;
    }

    function _parsePermitData(bytes calldata memo) internal pure returns (uint64 expiry, address holder) {
        assembly {
            expiry := calldataload(add(memo.offset, 0xc))
            holder := calldataload(add(memo.offset, 0x20))
        }
    }

    function _commitDepositSpender() internal pure returns (address depositSpender) {
        (uint256 memoPos, uint256 memoSize) = _commit_memo_pos_and_size();
        uint256 offset = memoPos + memoSize;
        bytes32 r; 
        bytes32 vs;
        assembly {
            r := calldataload(offset)
            vs := calldataload(add(offset, 32))
        }
        return ECDSA.recover(ECDSA.toEthSignedMessageHash(bytes32(_transfer_nullifier())), r, vs);
    }
}