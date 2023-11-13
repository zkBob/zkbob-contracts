// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "forge-std/console2.sol";

contract CustomABIDecoder {
    uint256 constant transfer_nullifier_pos = 4;
    uint256 constant transfer_nullifier_size = 32;
    uint256 constant uint256_size = 32;

    function _loaduint256(uint256 pos) internal pure returns (uint256 r) {
        assembly {
            r := calldataload(pos)
        }
    }
    function _loadaddress(uint256 pos) internal pure returns (address r) {
        assembly {
            r := calldataload(pos)
        }
    }

    function _transfer_nullifier() internal pure returns (uint256 r) {
        r = _loaduint256(transfer_nullifier_pos);
    }

    uint256 constant transfer_out_commit_pos = transfer_nullifier_pos + transfer_nullifier_size;
    uint256 constant transfer_out_commit_size = 32;

    function _transfer_out_commit() internal pure returns (uint256 r) {
        
        r = _loaduint256(transfer_out_commit_pos);
        uint offset = transfer_out_commit_pos;
        bytes calldata r_bytes;
        assembly {
            r_bytes.offset := offset
            r_bytes.length := 32
        }
    }

    uint256 constant transfer_index_pos = transfer_out_commit_pos + transfer_out_commit_size;
    uint256 constant transfer_index_size = 6;

    function _transfer_index() internal pure returns (uint48 r) {
        r = uint48(_loaduint256(transfer_index_pos + transfer_index_size - uint256_size));
    }

    uint256 constant transfer_energy_amount_pos = transfer_index_pos + transfer_index_size;
    uint256 constant transfer_energy_amount_size = 14;

    function _transfer_energy_amount() internal pure returns (int112 r) {
        r = int112(uint112(_loaduint256(transfer_energy_amount_pos + transfer_energy_amount_size - uint256_size)));
    }

    uint256 constant transfer_token_amount_pos = transfer_energy_amount_pos + transfer_energy_amount_size;
    uint256 constant transfer_token_amount_size = 8;

    function _transfer_token_amount() internal view returns (int64 r) {
        r = int64(uint64(_loaduint256(transfer_token_amount_pos + transfer_token_amount_size - uint256_size)));
    }

    uint256 constant transfer_proof_pos = transfer_token_amount_pos + transfer_token_amount_size;
    uint256 constant transfer_proof_size = 256;

    function _transfer_proof() internal pure returns (uint256[8] calldata r) {
        uint256 pos = transfer_proof_pos;
        assembly {
            r := pos
        }
    }

    uint256 constant tree_root_after_pos = transfer_proof_pos + transfer_proof_size;
    uint256 constant tree_root_after_size = 32;

    function _tree_root_after() internal pure returns (uint256 r) {
        r = _loaduint256(tree_root_after_pos);
    }

    uint256 constant tree_proof_pos = tree_root_after_pos + tree_root_after_size;
    uint256 constant tree_proof_size = 256;

    function _tree_proof() internal pure returns (uint256[8] calldata r) {
        uint256 pos = tree_proof_pos;
        assembly {
            r := pos
        }
    }

    uint256 constant tx_type_pos = tree_proof_pos + tree_proof_size;
    uint256 constant tx_type_size = 2;
    uint256 constant tx_type_mask = (1 << (tx_type_size * 8)) - 1;

    function _tx_type() internal pure returns (uint256 r) {
        r = _loaduint256(tx_type_pos + tx_type_size - uint256_size) & tx_type_mask;
    }

    uint256 constant memo_data_size_pos = tx_type_pos + tx_type_size;
    uint256 constant memo_data_size_size = 2;
    uint256 constant memo_data_size_mask = (1 << (memo_data_size_size * 8)) - 1;

    uint256 constant memo_data_pos = memo_data_size_pos + memo_data_size_size;

    function _memo_data_size() internal pure returns (uint256 r) {
        r = _loaduint256(memo_data_size_pos + memo_data_size_size - uint256_size) & memo_data_size_mask;
    }

    function _memo_data() internal pure returns (bytes calldata r) {
        uint256 offset = memo_data_pos;
        uint256 length = _memo_data_size();
        assembly {
            r.offset := offset
            r.length := length
        }
    }

    function _sign_r_vs_pos() internal pure returns (uint256) {
        return memo_data_pos + _memo_data_size();
    }

    uint256 constant sign_r_vs_size = 64;

    function _sign_r_vs() internal pure returns (bytes32 r, bytes32 vs) {
        uint256 offset = _sign_r_vs_pos();
        assembly {
            r := calldataload(offset)
            vs := calldataload(add(offset, 32))
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

    uint256 constant transfer_delta_size =
        transfer_index_size + transfer_energy_amount_size + transfer_token_amount_size;
    uint256 constant transfer_delta_mask = (1 << (transfer_delta_size * 8)) - 1;

    function _transfer_delta() internal pure returns (uint256 r) {
        r = _loaduint256(transfer_index_pos + transfer_delta_size - uint256_size) & transfer_delta_mask;
    }

    function _memo_fixed_size() internal pure returns (uint256 r) {
        uint256 t = _tx_type();
        if (t == 0 || t == 1) {
            // prover + proxy fee + prover fee
            // 20 + 8 + 8 = 36
            r = 36;
        } else if (t == 2) {
            // prover + proxy fee + prover fee + native amount + recipient
            // 36 + 8 + 20
            r = 64;
        } else if (t == 3) {
            // prover + proxy fee + prover fee + deadline + address
            // 36 + 8 + 20
            r = 64;
        } else {
            revert();
        }
    }

    function _memo_message() internal pure returns (bytes calldata r) {
        uint256 memo_fixed_size = _memo_fixed_size();
        uint256 offset = memo_data_pos + memo_fixed_size;
        uint256 length = _memo_data_size() - memo_fixed_size;
        assembly {
            r.offset := offset
            r.length := length
        }
    }

    // uint256 constant memo_fee_pos = memo_data_pos;
    uint256 constant memo_sequencer_data_pos = memo_data_pos;
    uint256 constant memo_prover_fee_size = memo_fee_size;
    uint256 constant memo_proxy_fee_size = memo_fee_size;
    uint256 constant memo_proxy_address_size = 20;
    uint256 constant memo_sequencer_data_size = memo_proxy_address_size + memo_proxy_fee_size + memo_prover_fee_size ;
    uint256 constant memo_tx_type_pos = memo_data_pos;
    
    uint256 constant memo_proxy_address_pos = memo_sequencer_data_pos;
    
    uint256 constant memo_proxy_fee_pos = memo_proxy_address_pos + memo_proxy_address_size;
    
    uint256 constant memo_prover_fee_pos = memo_proxy_fee_pos + memo_proxy_fee_size;

    function _memo_fee() internal pure returns (uint256 r) {
        r =  _loaduint256(
            memo_prover_fee_pos + memo_fee_size - uint256_size
        ) & memo_fee_mask;
    }

    // Withdraw specific data

    uint256 constant memo_native_amount_pos = memo_sequencer_data_pos + memo_sequencer_data_size;
    uint256 constant memo_native_amount_size = 8;
    uint256 constant memo_native_amount_mask = (1 << (memo_native_amount_size * 8)) - 1;

    uint256 constant memo_fee_size = 8;
    uint256 constant memo_fee_mask = (1 << (memo_fee_size * 8)) - 1;

    function _memo_proxy_address() internal pure returns (address r) {
        r = _loadaddress(memo_proxy_address_pos);
    }

    function _memo_native_amount() internal pure returns (uint256 r) {
        r = _loaduint256(memo_native_amount_pos + memo_native_amount_size - uint256_size) & memo_native_amount_mask;
    }

    uint256 constant memo_receiver_pos = memo_native_amount_pos + memo_native_amount_size;
    uint256 constant memo_receiver_size = 20;

    function _memo_receiver() internal pure returns (address r) {
        r = address(uint160(_loaduint256(memo_receiver_pos + memo_receiver_size - uint256_size)));
    }

    // Permittable token deposit specific data
    //This is mutualy exclusive with native amount i.e. they both take the same position in transactions of respective type

    uint256 constant memo_permit_deadline_pos = memo_sequencer_data_pos + memo_sequencer_data_size;
    uint256 constant memo_permit_deadline_size = 8;

    function _memo_permit_deadline() internal pure returns (uint64 r) {
        r = uint64(_loaduint256(memo_permit_deadline_pos + memo_permit_deadline_size - uint256_size));
    }

    uint256 constant memo_permit_holder_pos = memo_permit_deadline_pos + memo_permit_deadline_size;
    uint256 constant memo_permit_holder_size = 20;

    function _memo_permit_holder() internal pure returns (address r) {
        r = address(uint160(_loaduint256(memo_permit_holder_pos + memo_permit_holder_size - uint256_size)));
    }

    function _parseCommitData() internal view returns (
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

    function bytesToHexString(
        bytes memory data
    ) public pure returns (string memory) {
        bytes memory hexString = new bytes(2 * data.length);

        for (uint256 i = 0; i < data.length; i++) {
            bytes2 b = bytes2(uint16(uint8(data[i])));
            bytes1 hi = bytes1(uint8(uint16(b)) / 16);
            bytes1 lo = bytes1(uint8(uint16(b)) % 16);

            hexString[2 * i] = char(hi);
            hexString[2 * i + 1] = char(lo);
        }

        return string(hexString);
    }

    function bytes32ToHexString(
        bytes32 data
    ) public pure returns (string memory) {
        bytes memory hexString = new bytes(2 * data.length);

        for (uint256 i = 0; i < data.length; i++) {
            bytes2 b = bytes2(uint16(uint8(data[i])));
            bytes1 hi = bytes1(uint8(uint16(b)) / 16);
            bytes1 lo = bytes1(uint8(uint16(b)) % 16);

            hexString[2 * i] = char(hi);
            hexString[2 * i + 1] = char(lo);
        }

        return string(hexString);
    }
    
    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) {
            return bytes1(uint8(b) + 0x30);
        } else {
            return bytes1(uint8(b) + 0x57);
        }
    }
}
