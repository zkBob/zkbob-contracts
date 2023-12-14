pragma solidity 0.8.15;
import "../../../src/zkbob/ZkBobPool.sol";
import "../../utils/Ownable.sol";
import "../utils/CustomABIDecoder.sol";

contract MPCWrapper is Ownable, CustomABIDecoder {

    address[] private signers;

    address operator;

    address public immutable pool;

    constructor(
        address _operator,
        address _pool
    ) {
        pool = _pool;
        _setOperator(_operator);
    }

    function _setOperator(address _operator) internal  {
        operator = _operator;
    }
    function setOperator(address _operator) external onlyOwner {
        _setOperator(_operator);
    }


    function setSigners(address[] calldata _signers) external onlyOwner {
        signers = _signers;
    }

    modifier requiresProofVerification() {
        require(isVerified(), "MPCWrapper: proof verification failed");
        _;
    }

    function isVerified() internal view  returns (bool) {
        (uint8 count, bytes calldata signatures) = _mpc_signatures();
        uint256 _signersCount = signers.length;
        require(count == _signersCount, "MPCWrapper: wrong quorum");
        uint256 offset = 0;
        assembly {
            offset := signatures.offset
        }
        for (uint256 index = 0; index < _signersCount; index++) {
            bytes32 r;
            bytes32 vs;
            assembly {
                r := calldataload(offset)
                vs := calldataload(add(32, offset))
                offset := add(offset, 64)
            }
            address signer = ECDSA.recover(
                ECDSA.toEthSignedMessageHash(keccak256(_mpc_message())),
                r,
                vs
            );
            if (signer != signers[index]) {
                return false;
            }
        }
        return true;
    }

    function transact() external requiresProofVerification {
        return propagate();
    }

    function appendDirectDeposit() external requiresProofVerification {
        return propagate();
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
            let result := call(gas(), contractAddress, 0, 0,calldatasize(), 0, 0)

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
