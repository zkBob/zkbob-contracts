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

    modifier paramsVerified(
        uint8 count,
        bytes calldata signatures
    ) {
        require(count == signers.length, "MPCWrapper: wrong quorum");
        uint256 length = msg.data.length - count * 64 - 1; //
        bytes calldata message;
        assembly 
        {
            message.offset:= 4 //we don't take the selector
            message.length:= length
        }
        require(checkQuorum(count, signatures,message));
        _;
    }
    modifier calldataVerified() {
        (uint8 count, bytes calldata signatures) = _mpc_signatures();
        require(count == signers.length, "MPCWrapper: wrong quorum");
        require(checkQuorum(count, signatures, _mpc_message()));
        _;
    }

    function checkQuorum(
        uint8 count,
        bytes calldata signatures,
        bytes calldata message
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
            address signer = ECDSA.recover(
                ECDSA.toEthSignedMessageHash(keccak256(message)),
                r,
                vs
            );
            if (signer != signers[index]) {
                return false;
            }
        }
        return true;
    }
    function transact() external calldataVerified {
        return propagate();
    }

    function appendDirectDepositsMPC(
        uint256 _root_after,
        uint256[] calldata _indices,
        uint256 _out_commit,
        uint256[8] calldata _batch_deposit_proof,
        uint256[8] calldata _tree_proof,
        uint8 mpc_count,
        bytes calldata signatures
    )
        external
        paramsVerified(
            mpc_count,
            signatures
        )

    {
        require(true);
        // IZkBobPool(pool).appendDirectDeposits(
        //     _root_after,
        //     _indices,
        //     _out_commit,
        //     _batch_deposit_proof,
        //     _tree_proof
        // );
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
