// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {PriorityQueue, PriorityOperation} from "./PriorityQueue.sol";
import {ZkBobPool} from "../ZkBobPool.sol";
import {SequencerABIDecoder} from "./SequencerABIDecoder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Permit} from "../../interfaces/IERC20Permit.sol";
import {EIP1967Admin} from "../../proxy/EIP1967Admin.sol";
import {Ownable} from "../../utils/Ownable.sol";
import {console2} from "forge-std/console2.sol";

contract ZkBobSequencer is SequencerABIDecoder, EIP1967Admin, Ownable {
    using PriorityQueue for PriorityQueue.Queue;
    using SafeERC20 for IERC20;

    bytes4 internal constant MESSAGE_PREFIX_COMMON_V1 = 0x00000000;
    uint16 public constant DEPOSIT = uint16(0);
    uint16 public constant PERMIT_DEPOSIT = uint16(3);

    // Queue of operations
    PriorityQueue.Queue priorityQueue;
    
    // Pool contract, this contract is operator of the pool
    ZkBobPool pool;

    // Last time when queue was updated
    uint256 lastQueueUpdateTimestamp;

    // Pending state
    mapping(uint256 => bool) public pendingNullifiers;
    mapping(uint256 => bool) public pendingDirectDeposits;

    uint64 public expirationTime;
    uint64 public gracePeriod;

    mapping(address => bool) public authorizedProvers;
    bool public isProverWhitelistEnabled;

    event Commited(); // TODO: Fill the data
    event DirectDepositCommited();
    event Proved();
    event Rejected();
    event Skipped();

    modifier onlyAuthorizedProver() {
        require(isProverWhitelistEnabled == false || authorizedProvers[msg.sender] == true, "ZkBobSequencer: not authorized");
        _;
    }

    constructor(address _pool, uint64 _expirationTime, uint64 _gracePeriod, bool _isProverWhitelistEnabled) {
        pool = ZkBobPool(_pool);
        expirationTime = _expirationTime;
        gracePeriod = _gracePeriod;
        isProverWhitelistEnabled = _isProverWhitelistEnabled;
    }

    function setExpirationTime(uint64 _expirationTime) external onlyOwner {
        expirationTime = _expirationTime;
    }

    function setGracePeriod(uint64 _gracePeriod) external onlyOwner {
        gracePeriod = _gracePeriod;
    }

    function setProverWhitelistEnabled(bool _isProverWhitelistEnabled) external onlyOwner {
        isProverWhitelistEnabled = _isProverWhitelistEnabled;
    }

    function setAuthorizedProvers(address[] memory _provers, bool[] memory _isAuthorized) external onlyOwner {
        require(_provers.length == _isAuthorized.length, "ZkBobSequencer: invalid input");
        for (uint256 i = 0; i < _provers.length; i++) {
            authorizedProvers[_provers[i]] = _isAuthorized[i];
        }
    }

    // Possible problems here:
    // 1. Malicious user can front run a prover and the prover spend some gas without any result
    function commit() external onlyAuthorizedProver {
        (
            uint256 nullifier,
            uint256 outCommit,
            uint48 index,
            uint256 transferDelta,
            uint256[8] calldata transferProof,
            uint16 txType,
            bytes calldata memo
        ) = _parseCommitCalldata();
        
        require(pendingNullifiers[nullifier] == false, "ZkBobSequencer: nullifier is already pending");
        require(pool.nullifiers(nullifier) == 0, "ZkBobSequencer: nullifier is spent");
        require(msg.sender == _parseProver(memo), "ZkBobSequencer: not authorized");
        require(uint96(index) <= pool.pool_index(), "ZkBobSequencer: index is too high");
        require(pool.transfer_verifier().verifyProof(transfer_pub(index, nullifier, outCommit, transferDelta, memo), transferProof), "ZkBobSequencer: invalid proof");
        require(_parseMessagePrefix(memo, txType) == MESSAGE_PREFIX_COMMON_V1, "ZkBobPool: bad message prefix");
        
        _claimDepositProxyFee(txType, memo, nullifier);

        bytes32 hash = _commitHash(nullifier, outCommit, transferDelta, transferProof, memo);
        PriorityOperation memory op = PriorityOperation(hash, nullifier, new uint256[](0), block.timestamp);
        priorityQueue.pushBack(op);
        pendingNullifiers[nullifier] = true;

        emit Commited();
    }

    // Possible problems here:
    // 1. Malicious user can commit a bad operation (low fees, problems with compliance, etc.) so there is no prover that will be ready to prove it
    //    In this case the prioirity queue will be locked until the expiration time
    function prove() onlyAuthorizedProver external {
        PriorityOperation memory op = _popFirstUnexpiredOperation();

        uint256 nullifier = _transfer_nullifier();
        bytes calldata memo = _memo_data();
        uint256[8] calldata transferProof = _transfer_proof();

        require(
            op.commitHash == _commitHash(nullifier, _transfer_out_commit(), _transfer_delta(), transferProof, memo),
            "ZkBobSequencer: invalid commit hash"
        );

        address prover = _parseProver(memo);
        uint256 timestamp = _max(op.timestamp, lastQueueUpdateTimestamp);
        require(msg.sender == prover || block.timestamp > timestamp + gracePeriod, "ZkBobSequencer: not authorized");

        lastQueueUpdateTimestamp = block.timestamp;
        delete pendingNullifiers[nullifier];

        (bool success, string memory revertReason) = _propagateToPool(ZkBobPool.transact.selector);

        // We remove the commitment from the queue regardless of the result of the call to pool contract
        // If we check that the prover is not malicious then the tx is not valid because of the limits or
        // absence of funds so it can't be proved
        if (success) {
            emit Proved();
        } else {
            // We should revert if the tree proof is invalid since the malicious prover can
            // send invalid proof to skip the operation even though the operation is valid
            _revertIfEquals(revertReason, "ZkBobPool: bad tree proof");
            emit Rejected();
        }
    }

    function commitDirectDeposits(
        uint256[] calldata _indices,
        uint256 _out_commit,
        uint256[8] memory _batch_deposit_proof
    )
        external onlyAuthorizedProver
    {
        // TODO: access control to prevent race condition
        
        uint256 hashsum = pool.direct_deposit_queue().validateBatch(_indices, _out_commit);
        for (uint256 i = 0; i < _indices.length; i++) {
            require(pendingDirectDeposits[_indices[i]] == false, "ZkBobSequencer: direct deposit is already in the queue");
        }

        // verify that _out_commit corresponds to zero output account + 16 chosen notes + 111 empty notes
        require(
            pool.batch_deposit_verifier().verifyProof([hashsum], _batch_deposit_proof), "ZkBobSequencer: bad batch deposit proof"
        );

        // Save pending indices
        for (uint256 i = 0; i < _indices.length; i++) {
            pendingDirectDeposits[_indices[i]] = true;
        }

        // Save operation in priority queue
        bytes32 hash = _commitDirectDepositHash(_indices, _out_commit, _batch_deposit_proof);
        PriorityOperation memory op = PriorityOperation(hash, uint256(0), _indices, block.timestamp);
        priorityQueue.pushBack(op);

        emit DirectDepositCommited();
    }

    function proveDirectDeposit(
        uint256 _root_after,
        uint256[] calldata _indices,
        uint256 _out_commit,
        uint256[8] memory _batch_deposit_proof,
        uint256[8] memory _tree_proof
    ) external onlyAuthorizedProver {
        PriorityOperation memory op = _popFirstUnexpiredOperation();

        require(
            op.commitHash == _commitDirectDepositHash(_indices, _out_commit, _batch_deposit_proof),
            "ZkBobSequencer: invalid commit hash"
        );

        // TODO: Access control to prevent race condition

        lastQueueUpdateTimestamp = block.timestamp;
        for (uint256 i = 0; i < op.directDeposits.length; i++) {
            delete pendingDirectDeposits[op.directDeposits[i]];
        }

        (bool success, string memory revertReason) = _propagateToPool(ZkBobPool.appendDirectDeposits.selector);

        if (success) {
            emit Proved();
        } else {
            // We should revert if the tree proof is invalid since the malicious prover can
            // send invalid proof to skip the operation even though the operation is valid
            _revertIfEquals(revertReason, "ZkBobPool: bad tree proof");
            emit Rejected();
        }
    }

    function _claimDepositProxyFee(uint16 _txType, bytes calldata _memo, uint256 _nullifier) internal {
        int256 fee = int64(_parseProxyFee(_memo));
        if (_txType == DEPOSIT) {
            pool.claimFee(_commitDepositSpender(), fee);
        } else if (_txType == PERMIT_DEPOSIT) {
            (uint64 expiry, address _user) = _parsePermitData(_memo);
            (uint8 v, bytes32 r, bytes32 s) = _permittable_signature_proxy_fee();
            pool.claimFeeUsingPermit(
                _user,
                _nullifier,
                fee,
                expiry,
                v,
                r,
                s
            );
        }
    }

    function _root() override internal view  returns (uint256){
        return pool.roots(pool.pool_index());
    }

    function _pool_id() override internal view returns (uint256){
        return pool.pool_id();
    }

    function _popFirstUnexpiredOperation() internal returns (PriorityOperation memory) {
        PriorityOperation memory op = priorityQueue.popFront();
        uint256 timestamp = _max(op.timestamp, lastQueueUpdateTimestamp);
        while (timestamp + expirationTime < block.timestamp) {
            delete pendingNullifiers[op.nullifier];
            for (uint256 i = 0; i < op.directDeposits.length; i++) {
                delete pendingDirectDeposits[op.directDeposits[i]];
            }
            // TODO: is it correct?
            lastQueueUpdateTimestamp = op.timestamp + expirationTime;
            emit Skipped();
            op = priorityQueue.popFront();
            timestamp = _max(op.timestamp, lastQueueUpdateTimestamp);
        }
        require(op.commitHash != bytes32(0), "ZkBobSequencer: no pending operations");
        return op;
    }
    
    function _commitHash(
        uint256 nullifier,
        uint256 out_commit,
        uint256 transfer_delta,
        uint256[8] calldata transfer_proof,
        bytes calldata memo
    ) internal pure returns (bytes32) {
        // TODO: check that it is enough
        // Add some prefix?
        return keccak256(abi.encodePacked(nullifier, out_commit, transfer_delta, transfer_proof, memo));
    }

    function _commitDirectDepositHash(
        uint256[] calldata _indices,
        uint256 _out_commit,
        uint256[8] memory _batch_deposit_proof
    ) internal pure returns (bytes32) {
        // Add some prefix?
        return keccak256(abi.encodePacked(_indices, _out_commit, _batch_deposit_proof));
    }

    function transfer_pub(
        uint48 index, 
        uint256 nullifier, 
        uint256 outCommit, 
        uint256 transferDelta, 
        bytes calldata memo
    ) internal view returns (uint256[5] memory r) {
        r[0] = pool.roots(index);
        r[1] = nullifier;
        r[2] = outCommit;
        r[3] = transferDelta + (pool.pool_id() << (transfer_delta_size * 8));
        r[4] = uint256(keccak256(memo)) % R;
    }

    function _propagateToPool(bytes4 selector) internal returns (bool success, string memory revertReason) {
        (bool result, bytes memory data) = address(pool).call(abi.encodePacked(selector, msg.data[4:]));
        
        success = result;
        if (!result && data.length >= 68) {
            assembly {
                data := add(data, 0x04)
            }
            revertReason = abi.decode(data, (string));
        }
    }

    function _max(uint256 a, uint256 b) internal pure returns (uint256 maxValue) {
        maxValue = a;
        if (b > a) {
            maxValue = b;
        }
    }

    function _revertIfEquals(string memory reason, string memory revertReason) internal pure {
        require(keccak256(abi.encodePacked((reason))) != keccak256(abi.encodePacked((revertReason))), revertReason);
    }

    function pendingOperation() external view returns (PriorityOperation memory op) {
        require(!priorityQueue.isEmpty(), "ZkBobSequencer: queue is empty");
        
        uint256 head = priorityQueue.getFirstUnprocessedPriorityTx();
        uint256 tail = priorityQueue.getTotalPriorityTxs();
        for (uint256 i = head; i <= tail; i++) {
            if (op.timestamp + expirationTime >= block.timestamp) {
                op = priorityQueue.get(i);
                break;
            }
        }
        require(op.commitHash != bytes32(0), "ZkBobSequencer: no pending operations");
    }
}