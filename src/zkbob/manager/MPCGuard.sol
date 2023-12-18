pragma solidity 0.8.15;
import "../../../src/zkbob/ZkBobPool.sol";
import "../../utils/Ownable.sol";
import "../utils/CustomABIDecoder.sol";

import "../../interfaces/IZkBobPool.sol";

contract MPCGuard is Ownable, CustomABIDecoder {
    address[] private guards;

    address operator;

    address public immutable pool;

    uint256 constant SIGNATURE_SIZE = 64;

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

    function setGuards(address[] calldata _guards) external onlyOwner {
        guards = _guards;
    }

    function digest(bytes memory data) internal pure returns (bytes32) {
        return ECDSA.toEthSignedMessageHash(keccak256(data));
    }

    modifier calldataVerified() {
        (uint8 count, bytes calldata signatures) = _mpc_signatures();
        require(count == guards.length, "MPCWrapper: wrong quorum");
        ZkBobPool poolContract = ZkBobPool(pool);
        uint256 currentRoot = poolContract.roots(poolContract.pool_index());
        uint256 transferRoot = poolContract.roots(_transfer_index());
        require(
            checkQuorum(
                signatures,
                digest(
                    abi.encodePacked(
                        _mpc_message(),
                        transferRoot,
                        currentRoot,
                        poolContract.pool_id()
                    )
                )
            ),
            "MPCWrapper: wrong quorum"
        );
        _;
    }

    function checkQuorum(
        bytes calldata signatures,
        bytes32 _digest
    ) internal view returns (bool) {
        uint256 offset = 0;
        assembly {
            offset := signatures.offset
        }
        for (uint256 index = 0; index < guards.length; index++) {
            bytes32 r;
            bytes32 vs;
            assembly {
                r := calldataload(offset)
                vs := calldataload(add(32, offset))
                offset := add(offset, 64)
            }
            address signer = ECDSA.recover(_digest, r, vs);
            if (signer != guards[index]) {
                return false;
            }
        }
        return true;
    }

    function transact() external calldataVerified onlyOperator {
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
        bytes calldata signatures
    ) external onlyOperator {
        require(
            signatures.length == guards.length * SIGNATURE_SIZE,
            "MPCWrapper: wrong quorum"
        );

        ZkBobPool poolContract = ZkBobPool(pool);

        bytes memory mpc_message = abi.encodePacked(
            ZkBobPool(pool).appendDirectDeposits.selector,
            _root_after,
            _indices,
            _out_commit,
            _batch_deposit_proof,
            _tree_proof,
            poolContract.roots(poolContract.pool_index()),
            poolContract.pool_id()
        );

        require(checkQuorum(signatures, digest(mpc_message)));
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
        uint256 _calldatasize = _mpc_signatures_pos(); //we don't need to propagate signatures
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, _calldatasize)

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := call(
                gas(),
                contractAddress,
                0,
                0,
                _calldatasize,
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
