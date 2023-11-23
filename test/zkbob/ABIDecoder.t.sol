pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {SequencerABIDecoder} from "../../src/zkbob/sequencer/SequencerABIDecoder.sol";

contract DummyParser is SequencerABIDecoder {
    function _root() internal view override returns (uint256) {
        return uint256(0);
    }

    function _pool_id() internal view override returns (uint256) {
        return uint256(0);
    }

    function parseCommitCalldata()
        external
        returns (
            uint256 nullifier,
            uint256 outCommit,
            uint48 transferIndex,
            uint256 transferDelta,
            uint256[8] calldata transferProof,
            uint16 txType,
            bytes calldata memo
        )
    {
        return _parseCommitCalldata();
    }
}
uint256 constant transfer_delta_mask = (1 << (28 * 8)) - 1;

contract ABIDecoder is Test {
    address _parser;

    function setUp() external {
        DummyParser parser = new DummyParser();
        _parser = address(parser);
    }

    function _randFR() internal view returns (uint256) {
        return
            uint256(keccak256(abi.encode(gasleft()))) %
            21888242871839275222246405745257275088696311157297823662689037894645226208583;
    }

    function _encodeWithdrawal(
        uint256 _amount,
        uint64 _proxyFee,
        uint64 _proverFee,
        address _prover,
        address receiver
    )
        internal
        
        returns (
            bytes memory commitData,
            bytes memory proveData,
            bytes32 nullifier,
            bytes memory transfer_delta_bytes,
            bytes memory memo
        )
    {
        nullifier = bytes32(_randFR());
        transfer_delta_bytes = abi.encodePacked( //28
            uint48(0), //index 6
            uint112(0), //energy 14
            int64(-int256((_amount))) //8
        );


        uint256 foo  = uint256(bytes32(transfer_delta_bytes)) & transfer_delta_mask;
        emit log_uint(foo);
        commitData = abi.encodePacked(
            // ZkBobSequencer.commit.selector, //4
            nullifier, //32 nullifier
            new bytes(32), //32 out_commit
            transfer_delta_bytes
        ); //96
        for (uint256 i = 0; i < 8; i++) {
            commitData = abi.encodePacked(commitData, new bytes(32)); //tx proof(8)*32 = 256
        }

        proveData = commitData;

        for (uint256 i = 0; i < 9; i++) {
            proveData = abi.encodePacked(proveData, _randFR()); //tx proof(8)*8 + root(1)*8 + tree proof(8)*8 = 136
        }

        memo = abi.encodePacked( //100 byte
            // fixed size 20+8+8+8+20 = 64
            bytes20(_prover), //20
            _proxyFee, //8
            _proverFee, //8
            int64(0), // native amount, 8 bytes
            receiver, // receiver 20 bytes
            // message = 20+8 = 28 bytes
            bytes4(0x01000000), // 1 item
            _randFR() //32 //out account mock
        );

        commitData = abi.encodePacked(
            commitData,
            uint16(2), //withdrawal,
            uint16(memo.length),
            memo
        );

        proveData = abi.encodePacked(
            proveData,
            uint16(2), //withdrawal,
            memo.length,
            memo
        );
    }

    address _prover1 = makeAddr("prover1");
    address _user1 = makeAddr("user1");

    function testParseWithdrawalCommitData() external {
        uint256 _amount = uint256(9_960_000_000);
        uint64 _proxyFee = uint64(10_000_000);
        uint64 _proverFee = uint64(30_000_000);
        (
            bytes memory commit_data,
            bytes memory prove_data,
            bytes32 nullifier,
            bytes memory transfer_delta_bytes,
            bytes memory memo
        ) = _encodeWithdrawal(_amount, _proxyFee, _proverFee, _prover1, _user1);

        (bool success, bytes memory result) = address(_parser).call(
            abi.encodePacked(
                DummyParser.parseCommitCalldata.selector,
                commit_data
            )
        );
        assert(success);
        emit log_bytes(result);
        (
            
            ,//uint256 parsed_nullifier,
            ,// uint256 parsed_outCommit,
            ,// uint48 parsed_transferIndex,
            ,// uint256 parsed_transferDelta,
            ,// uint256[8] memory transferProof,
            ,// uint16 parsed_txType,
            bytes memory parsed_memo
        ) = abi.decode(
                result,
                (
                    uint256,
                    uint256,
                    uint48,
                    uint256,
                    uint256[8],
                    uint16,
                    bytes
                )
            );

        // assertEq(memo, parsed_memo);
    }
}
