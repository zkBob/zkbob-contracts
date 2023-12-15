pragma solidity 0.8.15;
import "../../../src/zkbob/ZkBobPool.sol";
import "../../utils/Ownable.sol";
import "../utils/CustomABIDecoder.sol";

import "../../interfaces/IZkBobPool.sol";

contract MPCWrapper is Ownable, CustomABIDecoder {
    address[] private signers;

    address operator;

    address public immutable pool;

    constructor(address _operator, address _pool) {
        pool = _pool;
        _setOperator(_operator);
    }

    /**
     * @dev Throws if called by any account other than the current relayer operator.
     */
    modifier onlyOperator() {
        require(operator == _msgSender(), "ZkBobPool: not an operator");
        _;
    }

    function _setOperator(address _operator) internal {
        operator = _operator;
    }

    function setOperator(address _operator) external onlyOwner {
        _setOperator(_operator);
    }

    function setSigners(address[] calldata _signers) external onlyOwner {
        signers = _signers;
    }

   
    modifier calldataVerified() {
        (uint8 count, bytes calldata signatures) = _mpc_signatures();
        require(count == signers.length, "MPCWrapper: wrong quorum");
        bytes32 digest = ECDSA.toEthSignedMessageHash(
            keccak256(_mpc_message())
        );
        require(checkQuorum(count, signatures, digest));
        _;
    }

    function checkQuorum(
        uint8 count,
        bytes calldata signatures,
        bytes32 _digest
    ) internal returns (bool) {
        uint256 offset = 0;
        assembly {
            offset := signatures.offset
        }
        for (uint256 index = 0; index < signers.length; index++) {
            bytes32 r;
            bytes32 vs;
            assembly {
                r := calldataload(offset)
                vs := calldataload(add(32, offset))
                offset := add(offset, 64)
            }
            address signer = ECDSA.recover(_digest, r, vs);
            if (signer != signers[index]) {
                return false;
            }
        }
        return true;
    }

    function transact() external calldataVerified {
        return propagate();
    }

    /**
     * @notice _tree_proof must be uint256[8] memory to avoid
     * https://soliditylang.org/blog/2022/08/08/calldata-tuple-reencoding-head-overflow-bug/
     */
    function appendDirectDepositsMPC(
        uint256 _root_after,
        uint256[] calldata _indices,
        uint256 _out_commit,
        uint256[8] calldata _batch_deposit_proof,
        uint256[8] memory _tree_proof,
        uint8 mpc_count,
        bytes calldata signatures
    ) external {
        require(mpc_count == signers.length, "MPCWrapper: wrong quorum");

        bytes memory mpc_message = abi.encodePacked(
            _root_after,
            _indices,
            _out_commit,
            _batch_deposit_proof,
            _tree_proof
        );

        bytes32 digest = ECDSA.toEthSignedMessageHash(keccak256(mpc_message));

        require(checkQuorum(mpc_count, signatures, digest));
        IZkBobPool(pool).appendDirectDeposits(
            _root_after,
            _indices,
            _out_commit,
            _batch_deposit_proof,
            _tree_proof
        );
    }

    function propagate() internal {
        address contractAddress = pool;
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := call(
                gas(),
                contractAddress,
                0,
                0,
                calldatasize(),
                0,
                0
            )

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
