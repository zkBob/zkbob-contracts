// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {PriorityQueue, PriorityOperation} from "./PriorityQueue.sol";
import {ZkBobPool} from "../ZkBobPool.sol";
import {MemoUtils} from "./MemoUtils.sol";
import {SequencerABIDecoder} from "./SequencerABIDecoder.sol";
import {ZkBobDirectDepositQueue} from "../ZkBobDirectDepositQueue.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20Permit} from "../../interfaces/IERC20Permit.sol";

contract ZkBobSequencer is SequencerABIDecoder, MemoUtils {
    using PriorityQueue for PriorityQueue.Queue;
    using SafeERC20 for IERC20;

    uint256 constant TRANSFER_DELTA_SIZE = 28;
    bytes4 internal constant MESSAGE_PREFIX_COMMON_V1 = 0x00000000;
    // TODO: make it configurable
    uint256 public constant EXPIRATION_TIME = 1 hours;
    uint256 public constant PROXY_GRACE_PERIOD = 10 minutes;

    // Queue of operations
    PriorityQueue.Queue priorityQueue;
    
    // Pool contract, this contract is operator of the pool
    ZkBobPool _pool;

    // Accumulated fees for each prover
    mapping(address => uint256) public accumulatedFees;

    // Last time when queue was updated
    uint256 lastQueueUpdateTimestamp;

    mapping(uint256 => bool) public pendingNullifiers;
    mapping(uint256 => bool) public pendingDirectDeposits;

    uint256 immutable TOKEN_DENOMINATOR;

    uint256 internal constant TOKEN_NUMERATOR = 1;

    event Commited(); // TODO: Fill the data
    event Proved();
    event Rejected();
    event Skipped();

    uint16 public constant PERMIT_DEPOSIT = uint16(3);

    constructor(address pool, uint256 _denominator) {
        _pool = ZkBobPool(pool);
        TOKEN_DENOMINATOR = _denominator;
    }

    function _transferFromByPermit(bytes memory _memo, uint256 _nullifier, int256 _tokenAmount) internal {

        (uint64 expiry, address _user) = _parsePermitData(_memo);

        
        (uint8 v, bytes32 r, bytes32 s) = _permittable_signature_proxy_fee();

        IERC20Permit(_pool.token()).receiveWithSaltedPermit(
            _user,
            uint256(_tokenAmount) * TOKEN_DENOMINATOR / TOKEN_NUMERATOR,
            expiry,
            bytes32(_nullifier),
            v,
            r,
            s
        );
    }
    // Possible problems here:
    // 1. Malicious user can front run a prover and the prover spend some gas without any result
    function commit() external {
        (
            uint256 nullifier,
            uint256 outCommit,
            uint48 index,
            uint256 transferDelta,
            ,
            uint256[8] calldata transferProof,
            uint16 txType,
            bytes calldata memo
        ) = _parseCommitData();

        (address proxy, uint64 proxyFee, ) = MemoUtils.parseFees(memo);
        
        require(pendingNullifiers[nullifier] == false, "ZkBobSequencer: nullifier is already pending");
        require(_pool.nullifiers(nullifier) == 0, "ZkBobSequencer: nullifier is spent");
        require(msg.sender == proxy, "ZkBobSequencer: not authorized");
        require(uint96(index) <= _pool.pool_index(), "ZkBobSequencer: index is too high");
        require(_pool.transfer_verifier().verifyProof(transfer_pub(index, nullifier, outCommit, transferDelta, memo), transferProof), "ZkBobSequencer: invalid proof");
        require(MemoUtils.parseMessagePrefix(memo, txType) == MESSAGE_PREFIX_COMMON_V1, "ZkBobPool: bad message prefix");
        
        //For permit based deposit we take the Proxy fee in advance
        if(txType == PERMIT_DEPOSIT) {
            _transferFromByPermit(memo, nullifier, int64(proxyFee));   
        }

        bytes32 hash = commitHash(nullifier, outCommit, transferDelta, transferProof, memo);
        PriorityOperation memory op = PriorityOperation(hash, nullifier, new uint256[](0), block.timestamp);
        priorityQueue.pushBack(op);
        pendingNullifiers[nullifier] = true;

        emit Commited();
    }

    // 1. Pop first operation from priority queue
    // 2. Verify that:
    //  1) If we are in the grace period then msg.sender can be only proxy, otherwice it can be anyone
    //  2) Provided commitData corresponds to saved commitHash
    //  3) Tree proof is correct according to the current pool state
    //  If this checks hold then the prover did everything correctly and if the _pool.transact will revert we can safely remove this operation from the queue
    // 3. Call _pool.transact with the provided data
    //  1) If call is successfull we store fees and emit event
    //  2) If call is not successfull we only emit event. Important: we don't revert
    // 4. Update lastQueueUpdateTimestamp and delete pending nullifier
    // Possible problems here:
    // 1. If the PROXY_GRACE_PERIOD is ended then anyone can prove the operation and race condition is possible
    //    We can prevent it by implementing some mechanism to pick a prover from the previous ones
    // 2. Malicious user can commit a bad operation (low fees, problems with compliance, etc.) so there is no prover that will be ready to prove it
    //    In this case the prioirity queue will be locked until the expiration time
    function prove() external {
        PriorityOperation memory op = popFirstUnexpiredOperation();

        uint256 nullifier = _transfer_nullifier();
        uint48 index = _transfer_index();
        bytes calldata memo = _memo_data();
        uint256[8] calldata transferProof = _transfer_proof();

        require(
            op.commitHash == commitHash(nullifier, _transfer_out_commit(), _transfer_delta(), transferProof, memo),
            "ZkBobSequencer: invalid commit hash"
        );

        (address proxy, uint256 proxy_fee, uint256 prover_fee) = MemoUtils.parseFees(memo);
        uint256 timestamp = max(op.timestamp, lastQueueUpdateTimestamp);
        if (block.timestamp <= timestamp + PROXY_GRACE_PERIOD) {
            require(msg.sender == proxy, "ZkBobSequencer: not authorized");
        }

        uint256[8] memory treeProof = _tree_proof();

        // We check proofs twice with the current implementation.
        // It should be possible to avoid it but we need to modify pool contract.
        require(
            _pool.tree_verifier().verifyProof(
                _tree_pub(_pool.roots(index)),
                treeProof
            ),
            "ZkBobSequencer: invalid proof"
        );

        lastQueueUpdateTimestamp = block.timestamp;
        delete pendingNullifiers[nullifier];

        uint256 accumulatedFeeBefore = _pool.accumulatedFee(address(this));
        bool success = propagateToPool(ZkBobPool.transact.selector);

        // We remove the commitment from the queue regardless of the result of the call to pool contract
        // If we check that the prover is not malicious then the tx is not valid because of the limits or
        // absence of funds so it can't be proved
        if (success) {
            // We need to store fees and add ability to withdraw them
            uint256 accruedFee = _pool.accumulatedFee(address(this)) -
                accumulatedFeeBefore;
                

            uint256 totalFee = prover_fee;
            if(_tx_type() != PERMIT_DEPOSIT) {
                totalFee+=proxy_fee;
            }
                require(
                totalFee == accruedFee,
                "ZkBobSequencer: fee is not correct"
            );
            accumulatedFees[proxy] += proxy_fee;
            accumulatedFees[msg.sender] += prover_fee;

            emit Proved();
        } else {
            emit Rejected();
        }
    }

    function commitDirectDeposits(
        uint256[] calldata _indices,
        uint256 _out_commit,
        uint256[8] memory _batch_deposit_proof
    )
        external
    {
        // TODO: access control to prevent race condition
        
        uint256 hashsum = _pool.direct_deposit_queue().validateBatch(_indices, _out_commit);
        for (uint256 i = 0; i < _indices.length; i++) {
            require(pendingDirectDeposits[_indices[i]] == false, "ZkBobSequencer: direct deposit is already in the queue");
        }

        // verify that _out_commit corresponds to zero output account + 16 chosen notes + 111 empty notes
        require(
            _pool.batch_deposit_verifier().verifyProof([hashsum], _batch_deposit_proof), "ZkBobSequencer: bad batch deposit proof"
        );

        // Save pending indices
        for (uint256 i = 0; i < _indices.length; i++) {
            pendingDirectDeposits[_indices[i]] = true;
        }

        // Save operation in priority queue
        bytes32 hash = commitDirectDepositHash(_indices, _out_commit, _batch_deposit_proof);
        PriorityOperation memory op = PriorityOperation(hash, uint256(0), _indices, block.timestamp);
        priorityQueue.pushBack(op);
    }

    function proveDirectDeposit(
        uint256 _root_after,
        uint256[] calldata _indices,
        uint256 _out_commit,
        uint256[8] memory _batch_deposit_proof,
        uint256[8] memory _tree_proof
    ) external {
        PriorityOperation memory op = popFirstUnexpiredOperation();

        require(
            op.commitHash == commitDirectDepositHash(_indices, _out_commit, _batch_deposit_proof),
            "ZkBobSequencer: invalid commit hash"
        );

        // TODO: Access control to prevent race condition

        // We need to check that the proof is valid to prevent the case when the prover is malicious
        uint256[3] memory tree_pub = [_pool.roots(_pool.pool_index()), _root_after, _out_commit];
        require(_pool.tree_verifier().verifyProof(tree_pub, _tree_proof), "ZkBobSequencer: bad tree proof");

        lastQueueUpdateTimestamp = block.timestamp;
        for (uint256 i = 0; i < op.directDeposits.length; i++) {
            delete pendingDirectDeposits[op.directDeposits[i]];
        }

        uint256 accumulatedFeeBefore = _pool.accumulatedFee(address(this));
        bool success = propagateToPool(ZkBobPool.appendDirectDeposits.selector);

        if (success) {
            uint256 fee = _pool.accumulatedFee(address(this)) - accumulatedFeeBefore;
            accumulatedFees[msg.sender] += fee;
            emit Proved();
        } else {
            emit Rejected();
        }
    }

    function withdrawFees() external {
        uint256 fee = accumulatedFees[msg.sender];
        require(fee > 0, "ZkBobSequencer: no fees to withdraw");
        
        fee = fee * _pool.TOKEN_DENOMINATOR() / _pool.TOKEN_NUMERATOR();
        address token = _pool.token();
        uint256 balance = IERC20(token).balanceOf(address(this));
        // TODO: it is not fair since some prover will pay for the gas more than others
        if (fee > balance) {
            _pool.withdrawFee(address(this), address(this));
        }
        balance = IERC20(token).balanceOf(address(this));
        require(fee <= balance, "ZkBobSequencer: fee exceeds balance");

        accumulatedFees[msg.sender] = 0;
        IERC20(token).safeTransfer(msg.sender, fee);
    }

    function _root() override internal view  returns (uint256){
        return _pool.roots(_pool.pool_index());
    }

    function _pool_id() override internal view returns (uint256){
        return _pool.pool_id();
    }

    function popFirstUnexpiredOperation() internal returns (PriorityOperation memory) {
        PriorityOperation memory op = priorityQueue.popFront();
        uint256 timestamp = max(op.timestamp, lastQueueUpdateTimestamp);
        while (timestamp + EXPIRATION_TIME < block.timestamp) {
            delete pendingNullifiers[op.nullifier];
            for (uint256 i = 0; i < op.directDeposits.length; i++) {
                delete pendingDirectDeposits[op.directDeposits[i]];
            }
            // TODO: is it correct?
            lastQueueUpdateTimestamp = op.timestamp + EXPIRATION_TIME;
            op = priorityQueue.popFront();
            timestamp = max(op.timestamp, lastQueueUpdateTimestamp);
        }
        return op;
    }
    
    function commitHash(
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

    function commitDirectDepositHash(
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
        r[0] = _pool.roots(index);
        r[1] = nullifier;
        r[2] = outCommit;
        r[3] = transferDelta + (_pool.pool_id() << (TRANSFER_DELTA_SIZE * 8));
        r[4] = uint256(keccak256(memo)) % R;
    }

    function propagateToPool(bytes4 selector) internal returns (bool success) {
        address poolAddress = address(_pool);
        bytes memory data = new bytes(msg.data.length);
        assembly {
            // TODO: check it
            mstore(add(data, 32), selector)
            let length := sub(calldatasize(), 4)
            calldatacopy(add(data, 36), 4, length)
        }
        (success, ) = poolAddress.call(data);
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256 maxValue) {
        maxValue = a;
        if (b > a) {
            maxValue = b;
        }
    }

    function pendingOperation() external view returns (PriorityOperation memory op) {
        require(!priorityQueue.isEmpty(), "ZkBobSequencer: queue is empty");
        
        uint256 head = priorityQueue.getFirstUnprocessedPriorityTx();
        uint256 tail = priorityQueue.getTotalPriorityTxs();
        bool found = false;
        for (uint256 i = head; i <= tail; i++) {
            if (op.timestamp + EXPIRATION_TIME >= block.timestamp) {
                op = priorityQueue.get(i);
                found = true;
                break;
            }
        }
        require(found, "ZkBobSequencer: no pending operations");
    }
}