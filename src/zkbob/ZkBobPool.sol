// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol";
import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "../interfaces/ITransferVerifier.sol";
import "../interfaces/ITreeVerifier.sol";
import "../interfaces/IBatchDepositVerifier.sol";
import "../interfaces/IMintableERC20.sol";
import "../interfaces/IOperatorManager.sol";
import "../interfaces/IERC20Permit.sol";
import "../interfaces/ITokenSeller.sol";
import "../interfaces/IZkBobDirectDepositQueue.sol";
import "../interfaces/IZkBobPool.sol";
import "../interfaces/IZkBobAccounting.sol";
import "./utils/Parameters.sol";
import "../utils/Ownable.sol";
import "../proxy/EIP1967Admin.sol";
import "../interfaces/IEnergyRedeemer.sol";
import "../utils/ExternalSload.sol";
import {PriorityQueue, PendingCommitment} from "./utils/PriorityQueue.sol";

/**
 * @title ZkBobPool
 * Shielded transactions pool
 */
abstract contract ZkBobPool is IZkBobPool, EIP1967Admin, Ownable, Parameters, ExternalSload {
    using SafeERC20 for IERC20;
    using PriorityQueue for PriorityQueue.Queue;

    uint256 internal constant MAX_POOL_ID = 0xffffff;
    bytes4 internal constant MESSAGE_PREFIX_COMMON_V1 = 0x00000000;
    uint256 internal constant FORCED_EXIT_MIN_DELAY = 1 hours;
    uint256 internal constant FORCED_EXIT_MAX_DELAY = 24 hours;

    uint256 internal immutable TOKEN_DENOMINATOR;
    uint256 internal constant TOKEN_NUMERATOR = 1;

    uint256 public immutable pool_id;
    ITransferVerifier public immutable transfer_verifier;
    ITreeVerifier public immutable tree_verifier;
    IBatchDepositVerifier public immutable batch_deposit_verifier;
    address public immutable token;
    IZkBobDirectDepositQueue public immutable direct_deposit_queue;

    uint256[2] private __deprecatedGap;
    mapping(uint256 => bytes32) public committedForcedExits;
    IEnergyRedeemer public redeemer;
    IZkBobAccounting public accounting;
    uint96 public pool_index;

    IOperatorManager public operatorManager;

    mapping(uint256 => uint256) public nullifiers;
    mapping(uint256 => uint256) public roots;
    bytes32 public all_messages_hash;

    mapping(address => uint256) public accumulatedFee;

    // TODO:
    // Is it safe to just add deprecated gap here and
    // call setTokenSeller() again after upgrade to fix storage layout?
    // Additionally, it makes sense to add __gap as well.
    // address private __deprecatedGap2;

    /**
     * @dev Queue of pending commitments to be included in the Merkle Tree.
     */
    PriorityQueue.Queue internal pendingCommitments;

    /**
     * @dev Timestamp of the last tree update.
     */
    uint64 public lastTreeUpdateTimestamp;

    /**
     * @dev The duration of the grace period within which only the prover who submitted the transaction
     * can submit the tree update proof.
     */
    uint64 public gracePeriod;

    /**
     * @dev The minimal fee required to be reserved for the prover who will submit the tree update proof.
     * This fee is used to prevent spamming the pool with transactions that don't incentivize provers
     * to provide tree update proof.
     */
    uint64 public minTreeUpdateFee;

    // uint256[50] __gap;

    event UpdateOperatorManager(address manager);
    event UpdateAccounting(address accounting);
    event UpdateRedeemer(address redeemer);
    event UpdateGracePeriod(uint64 gracePeriod);
    event UpdateMinTreeUpdateFee(uint64 minTreeUpdateFee);
    event WithdrawFee(address indexed operator, uint256 fee);

    event Message(uint256 indexed index, bytes32 indexed hash, bytes message);
    event RootUpdated(uint256 indexed index, uint256 root, uint256 commitment);

    event CommitForcedExit(
        uint256 indexed nullifier, address operator, address to, uint256 amount, uint256 exitStart, uint256 exitEnd
    );
    event CancelForcedExit(uint256 indexed nullifier);
    event ForcedExit(uint256 indexed index, uint256 indexed nullifier, address to, uint256 amount);

    constructor(
        uint256 __pool_id,
        address _token,
        ITransferVerifier _transfer_verifier,
        ITreeVerifier _tree_verifier,
        IBatchDepositVerifier _batch_deposit_verifier,
        address _direct_deposit_queue,
        uint256 _denominator
    ) {
        require(__pool_id <= MAX_POOL_ID, "ZkBobPool: exceeds max pool id");
        require(Address.isContract(_token), "ZkBobPool: not a contract");
        require(Address.isContract(address(_transfer_verifier)), "ZkBobPool: not a contract");
        require(Address.isContract(address(_tree_verifier)), "ZkBobPool: not a contract");
        require(Address.isContract(address(_batch_deposit_verifier)), "ZkBobPool: not a contract");
        require(Address.isContract(_direct_deposit_queue), "ZkBobPool: not a contract");
        require(TOKEN_NUMERATOR == 1 || _denominator == 1, "ZkBobPool: incorrect denominator");
        pool_id = __pool_id;
        token = _token;
        transfer_verifier = _transfer_verifier;
        tree_verifier = _tree_verifier;
        batch_deposit_verifier = _batch_deposit_verifier;
        direct_deposit_queue = IZkBobDirectDepositQueue(_direct_deposit_queue);

        TOKEN_DENOMINATOR = _denominator;
    }

    /**
     * @dev Throws if called by any account other than the current relayer operator.
     */
    modifier onlyOperator() {
        require(operatorManager.isOperator(_msgSender()), "ZkBobPool: not an operator");
        _;
    }

    /**
     * @dev Throws if minimal tree update fee is not set.
     */
    modifier minTreeUpdateFeeIsSet() {
        require(minTreeUpdateFee > 0, "ZkBobPool: minimal tree update fee is not set");
        _;
    }

    /**
     * @dev Initializes pool proxy storage.
     * Callable only once and only through EIP1967Proxy constructor / upgradeToAndCall.
     * @param _root initial empty merkle tree root.
     */
    function initialize(uint256 _root) external {
        require(msg.sender == address(this), "ZkBobPool: not initializer");
        require(roots[0] == 0, "ZkBobPool: already initialized");
        require(_root != 0, "ZkBobPool: zero root");
        roots[0] = _root;
    }

    /**
     * @dev Initializes pool index after contract upgrade.
     * @param _poolIndex current pool index.
     */
    function initializePoolIndex(uint96 _poolIndex) external {
        require(pool_index == 0 && roots[_poolIndex] > 0 && roots[_poolIndex + 128] == 0, "ZkBobPool: invalid index");
        pool_index = _poolIndex;
    }

    /**
     * @dev Updates used operator manager contract.
     * Callable only by the contract owner / proxy admin.
     * @param _operatorManager new operator manager implementation.
     */
    function setOperatorManager(IOperatorManager _operatorManager) external onlyOwner {
        require(address(_operatorManager) != address(0), "ZkBobPool: manager is zero address");
        operatorManager = _operatorManager;
        emit UpdateOperatorManager(address(_operatorManager));
    }

    /**
     * @dev Tells the denominator for converting pool token into zkBOB units.
     */
    function denominator() external view returns (uint256) {
        return TOKEN_NUMERATOR == 1 ? TOKEN_DENOMINATOR : (1 << 255) | TOKEN_NUMERATOR;
    }

    /**
     * @dev Returns the first pending commitment in the prioirty queue.
     * @return commitment commitment value.
     * @return privilegedProver prover that can submit the tree update proof within the grace period.
     * @return fee fee reserved for the prover who will submit the tree update proof.
     * @return timestamp commitment timestamp.
     * @return gracePeriodEnd timestamp when the grace period ends.
     */
    function pendingCommitment()
        external
        view
        returns (uint256 commitment, address privilegedProver, uint64 fee, uint64 timestamp, uint64 gracePeriodEnd)
    {
        PendingCommitment memory op = pendingCommitments.front();
        require(op.commitment != 0, "ZkBobPool: no pending commitment");
        uint64 gracePeriodStart = op.timestamp > lastTreeUpdateTimestamp ? op.timestamp : lastTreeUpdateTimestamp;
        gracePeriodEnd = gracePeriodStart + gracePeriod;
        return (op.commitment, op.prover, op.fee, op.timestamp, gracePeriodEnd);
    }

    /**
     * @dev Updates used accounting module.
     * Callable only by the contract owner / proxy admin.
     * @param _accounting new operator manager implementation.
     */
    function setAccounting(IZkBobAccounting _accounting) external onlyOwner {
        require(
            address(_accounting) == address(0) || Address.isContract(address(_accounting)), "ZkBobPool: not a contract"
        );
        accounting = _accounting;
        emit UpdateAccounting(address(_accounting));
    }

    /**
     * @dev Updates used energy redemption module.
     * Callable only by the contract owner / proxy admin.
     * @param _redeemer new energy redeemer implementation.
     */
    function setEnergyRedeemer(IEnergyRedeemer _redeemer) external onlyOwner {
        require(address(_redeemer) == address(0) || Address.isContract(address(_redeemer)), "ZkBobPool: not a contract");
        redeemer = _redeemer;
        emit UpdateRedeemer(address(_redeemer));
    }

    /**
     * @dev Updates grace period duration.
     * Callable only by the contract owner / proxy admin.
     * @param _gracePeriod new grace period duration.
     */
    function setGracePeriod(uint64 _gracePeriod) external onlyOwner {
        gracePeriod = _gracePeriod;
        emit UpdateGracePeriod(_gracePeriod);
    }

    /**
     * @dev Updates minimal fee required to be reserved for the prover who will submit the tree update proof.
     * Callable only by the contract owner / proxy admin.
     * @param _minTreeUpdateFee new minimal fee.
     */
    function setMinTreeUpdateFee(uint64 _minTreeUpdateFee) external onlyOwner {
        require(_minTreeUpdateFee > 0, "ZkBobPool: tree update fee can't be zero");
        minTreeUpdateFee = _minTreeUpdateFee;
        emit UpdateMinTreeUpdateFee(_minTreeUpdateFee);
    }

    function _root() internal view override returns (uint256) {
        return roots[_transfer_index()];
    }

    function _pool_id() internal view override returns (uint256) {
        return pool_id;
    }

    /**
     * @dev Converts given amount of tokens into native coins sent to the provided address.
     * @param _user native coins receiver address.
     * @param _tokenAmount amount to tokens to convert.
     * @return actual converted amount, might be less than requested amount.
     */
    function _withdrawNative(address _user, uint256 _tokenAmount) internal virtual returns (uint256);

    /**
     * @dev Performs token transfer using a signed permit signature.
     * @param _user token depositor address, should correspond to the signature author.
     * @param _nullifier nullifier and permit signature salt to avoid transaction data manipulation.
     * @param _tokenAmount amount to tokens to deposit.
     */
    function _transferFromByPermit(address _user, uint256 _nullifier, int256 _tokenAmount) internal virtual;

    /**
     * @dev Perform a zkBob pool transaction.
     * Callable only by the current operator.
     * Method uses a custom ABI encoding scheme described in CustomABIDecoder.
     * Single transact() call performs either deposit, withdrawal or shielded transfer operation.
     */
    function transactV2() external onlyOperator minTreeUpdateFeeIsSet {
        require(_version() == 2, "ZkBobPool: incorrect calldata version");

        address user = msg.sender;
        uint256 txType = _tx_type();
        if (txType == 0) {
            user = _deposit_spender();
        } else if (txType == 2) {
            user = _memo_receiver();
        } else if (txType == 3) {
            user = _memo_permit_holder();
        }
        int256 transfer_token_delta = _transfer_token_amount();

        (IZkBobAccounting acc, uint96 poolIndex) = (accounting, pool_index);
        if (address(acc) != address(0)) {
            // For private transfers, operator can receive any fee amount. As receiving a fee is basically a withdrawal,
            // we should consider operator's tier withdrawal limits respectfully.
            // For deposits, fee transfers can be left unbounded, since they are paid from the deposits themselves,
            // not from the pool funds.
            // For withdrawals, withdrawal amount that is checked against limits for specific user is already inclusive
            // of operator's fee, thus there is no need to consider it separately.
            acc.recordOperation(IZkBobAccounting.TxType.Common, user, transfer_token_delta);
        }

        uint256 nullifier = _transfer_nullifier();
        {
            require(msg.sender == _memo_prover_address(), "ZkBobPool: unauthorized");
            require(nullifiers[nullifier] == 0, "ZkBobPool: doublespend detected");
            require(_transfer_index() <= poolIndex, "ZkBobPool: transfer index out of bounds");
            require(transfer_verifier.verifyProof(_transfer_pub(), _transfer_proof()), "ZkBobPool: bad transfer proof");

            _appendCommitment(_transfer_out_commit(), uint64(_memo_tree_update_fee()), msg.sender);

            nullifiers[nullifier] = uint256(keccak256(abi.encodePacked(_transfer_out_commit(), _transfer_delta())));

            bytes memory message = _memo_message();
            // restrict memo message prefix (items count in little endian) to be < 2**16
            require(bytes4(message) & 0x0000ffff == MESSAGE_PREFIX_COMMON_V1, "ZkBobPool: bad message prefix");
            bytes32 message_hash = keccak256(message);
            bytes32 _all_messages_hash = keccak256(abi.encodePacked(all_messages_hash, message_hash));
            all_messages_hash = _all_messages_hash;

            // Since there is no way to skip commitments in the queue
            // we can precompute the index of this commitment in the merkle tree
            uint256 pendingIndex = poolIndex + 128 * pendingCommitments.getSize();
            emit Message(pendingIndex, _all_messages_hash, message);
        }

        uint256 transactFee = _memo_transact_fee();
        uint256 treeUpdateFee = _memo_tree_update_fee();

        require(treeUpdateFee >= minTreeUpdateFee, "ZkBobPool: tree update fee is too low");

        uint256 fee = transactFee + treeUpdateFee;

        int256 token_amount = transfer_token_delta + int256(fee);
        int256 energy_amount = _transfer_energy_amount();

        require(token_amount % int256(TOKEN_NUMERATOR) == 0, "ZkBobPool: incorrect token amount");

        if (txType == 0) {
            // Deposit
            require(transfer_token_delta > 0 && energy_amount == 0, "ZkBobPool: incorrect deposit amounts");
            IERC20(token).safeTransferFrom(
                user, address(this), uint256(token_amount) * TOKEN_DENOMINATOR / TOKEN_NUMERATOR
            );
        } else if (txType == 1) {
            // Transfer
            require(token_amount == 0 && energy_amount == 0, "ZkBobPool: incorrect transfer amounts");
        } else if (txType == 2) {
            // Withdraw
            require(token_amount <= 0 && energy_amount <= 0, "ZkBobPool: incorrect withdraw amounts");

            uint256 native_amount = _memo_native_amount() * TOKEN_DENOMINATOR / TOKEN_NUMERATOR;
            uint256 withdraw_amount = uint256(-token_amount) * TOKEN_DENOMINATOR / TOKEN_NUMERATOR;

            if (native_amount > 0) {
                withdraw_amount -= _withdrawNative(user, native_amount);
            }

            if (withdraw_amount > 0) {
                IERC20(token).safeTransfer(user, withdraw_amount);
            }

            if (energy_amount < 0) {
                redeemer.redeem(user, uint256(-energy_amount));
            }
        } else if (txType == 3) {
            // Permittable token deposit
            require(transfer_token_delta > 0 && energy_amount == 0, "ZkBobPool: incorrect deposit amounts");
            _transferFromByPermit(user, nullifier, token_amount);
        } else {
            revert("ZkBobPool: Incorrect transaction type");
        }

        if (fee > 0) {
            accumulatedFee[msg.sender] += transactFee;
        }
    }

    /**
     * @dev Appends a batch of direct deposits into a zkBob merkle tree.
     * Callable only by the current operator.
     * @param _indices list of indices for queued pending deposits.
     * @param _out_commit out commitment for output notes serialized from direct deposits.
     * @param _batch_deposit_proof snark proof for batch deposit verifier.
     */
    function appendDirectDeposits(
        uint256[] calldata _indices,
        uint256 _out_commit,
        uint256[8] memory _batch_deposit_proof
    )
        external
        onlyOperator
        minTreeUpdateFeeIsSet
    {
        (uint256 total, uint256 totalFee, uint256 hashsum, bytes memory message) =
            direct_deposit_queue.collect(_indices, _out_commit);

        (IZkBobAccounting acc, uint96 poolIndex) = (accounting, pool_index);
        if (address(acc) != address(0)) {
            acc.recordOperation(IZkBobAccounting.TxType.AppendDirectDeposits, address(0), int256(total));
        }

        // verify that _out_commit corresponds to zero output account + 16 chosen notes + 111 empty notes
        require(
            batch_deposit_verifier.verifyProof([hashsum], _batch_deposit_proof), "ZkBobPool: bad batch deposit proof"
        );

        // we reserve the minimal tree update fee for the prover who will submit the tree update proof
        require(totalFee >= minTreeUpdateFee, "ZkBobPool: tree update fee is too low");
        uint64 ddFee = uint64(totalFee) - minTreeUpdateFee;

        _appendCommitment(_out_commit, minTreeUpdateFee, msg.sender);

        bytes32 message_hash = keccak256(message);
        bytes32 _all_messages_hash = keccak256(abi.encodePacked(all_messages_hash, message_hash));
        all_messages_hash = _all_messages_hash;

        if (ddFee > 0) {
            accumulatedFee[msg.sender] += ddFee;
        }

        // Since there is no way to skip commitments in the queue
        // we can precompute the index of this commitment in the merkle tree
        uint256 pendingIndex = poolIndex + 128 * pendingCommitments.getSize();
        emit Message(pendingIndex, _all_messages_hash, message);
    }

    /**
     * @dev Updates pool index and merkle tree root if the provided proof is valid and
     * the proof corresponds to the pending commitment.
     * A prover that submitted the transfer proof has the grace period to submit the tree update proof.
     * @param _commitment pending commitment to be proven.
     * @param _proof snark proof for tree update verifier.
     * @param _rootAfter new merkle tree root.
     */
    function proveTreeUpdate(
        uint256 _commitment,
        uint256[8] calldata _proof,
        uint256 _rootAfter
    )
        external
        onlyOperator
    {
        PendingCommitment memory commitment = pendingCommitments.popFront();
        require(commitment.commitment == _commitment, "ZkBobPool: commitment mismatch");

        _validateGracePeriod(commitment.timestamp, commitment.prover);

        uint256[3] memory tree_pub = [roots[pool_index], _rootAfter, _commitment];
        require(tree_verifier.verifyProof(tree_pub, _proof), "ZkBobPool: bad tree proof");

        pool_index += 128;
        roots[pool_index] = _rootAfter;
        accumulatedFee[msg.sender] += commitment.fee;
        lastTreeUpdateTimestamp = uint64(block.timestamp);

        emit RootUpdated(pool_index, _rootAfter, _commitment);
    }

    /**
     * @dev Commits a forced withdrawal transaction for future execution after a set delay.
     * Forced exits can be executed during 23 hours after 1 hour passed since its commitment.
     * Account cannot be recovered after such forced exit.
     * any remaining or newly sent funds would be lost forever.
     * Accumulated account energy is forfeited.
     * @param _operator address that is allowed to call executeForcedExit, or address(0) if permissionless.
     * @param _to withdrawn funds receiver.
     * @param _amount total account balance to withdraw.
     * @param _index index of the merkle root used within proof.
     * @param _nullifier transfer nullifier to be used for withdrawal.
     * @param _out_commit out commitment for empty list of output notes.
     * @param _transfer_proof snark proof for transfer verifier.
     */
    function commitForcedExit(
        address _operator,
        address _to,
        uint256 _amount,
        uint256 _index,
        uint256 _nullifier,
        uint256 _out_commit,
        uint256[8] memory _transfer_proof
    )
        external
    {
        require(
            _amount > 0 && _amount % TOKEN_NUMERATOR == 0 && _amount <= 1 << 63, "ZkBobPool: incorrect token amount"
        );
        require(_index < type(uint48).max, "ZkBobPool: index too large");

        uint256 root = roots[_index];
        require(root > 0, "ZkBobPool: transfer index out of bounds");
        require(nullifiers[_nullifier] == 0, "ZkBobPool: doublespend detected");
        require(committedForcedExits[_nullifier] == 0, "ZkBobPool: already exists");

        uint256[5] memory transfer_pub = [
            root,
            _nullifier,
            _out_commit,
            (pool_id << 224) + (_index << 176) + uint64(-int64(uint64(_amount))),
            uint256(keccak256(abi.encodePacked(_to))) % R
        ];
        require(transfer_verifier.verifyProof(transfer_pub, _transfer_proof), "ZkBobPool: bad transfer proof");

        committedForcedExits[_nullifier] = _hashForcedExit(
            _operator, _to, _amount, block.timestamp + FORCED_EXIT_MIN_DELAY, block.timestamp + FORCED_EXIT_MAX_DELAY
        );

        emit CommitForcedExit(
            _nullifier,
            _operator,
            _to,
            _amount,
            block.timestamp + FORCED_EXIT_MIN_DELAY,
            block.timestamp + FORCED_EXIT_MAX_DELAY
        );
    }

    /**
     * @dev Performs a forced withdrawal by irreversibly killing an account.
     * Callable only by the operator, if set during latest call to the commitForcedExit.
     * Account cannot be recovered after such forced exit.
     * any remaining or newly sent funds would be lost forever.
     * Accumulated account energy is forfeited.
     * @param _nullifier transfer nullifier to be used for withdrawal.
     * @param _operator operator address set during commitForcedExit.
     * @param _to withdrawn funds receiver.
     * @param _amount total account balance to withdraw.
     * @param _exitStart exit window start timestamp, should match one calculated in commitForcedExit.
     * @param _exitEnd exit window end timestamp, should match one calculated in commitForcedExit.
     * @param _cancel cancel a previously submitted expired forced exit instead of executing it.
     */
    function executeForcedExit(
        uint256 _nullifier,
        address _operator,
        address _to,
        uint256 _amount,
        uint256 _exitStart,
        uint256 _exitEnd,
        bool _cancel
    )
        external
    {
        require(nullifiers[_nullifier] == 0, "ZkBobPool: doublespend detected");
        require(
            committedForcedExits[_nullifier] == _hashForcedExit(_operator, _to, _amount, _exitStart, _exitEnd),
            "ZkBobPool: invalid forced exit"
        );
        if (_cancel) {
            require(block.timestamp >= _exitEnd, "ZkBobPool: exit not expired");
            delete committedForcedExits[_nullifier];

            emit CancelForcedExit(_nullifier);
            return;
        }

        require(_operator == address(0) || _operator == msg.sender, "ZkBobPool: invalid caller");
        require(block.timestamp >= _exitStart && block.timestamp < _exitEnd, "ZkBobPool: exit not allowed");

        (IZkBobAccounting acc, uint96 poolIndex) = (accounting, pool_index);
        if (address(acc) != address(0)) {
            acc.recordOperation(IZkBobAccounting.TxType.ForcedExit, address(0), int256(_amount));
        }
        nullifiers[_nullifier] = poolIndex | uint256(0xdeaddeaddeaddeaddeaddeaddeaddeaddeaddeaddeaddead0000000000000000);

        IERC20(token).safeTransfer(_to, _amount * TOKEN_DENOMINATOR / TOKEN_NUMERATOR);

        emit ForcedExit(poolIndex, _nullifier, _to, _amount);
    }

    /**
     * @dev Records submitted direct deposit into the users limits.
     * Callable only by the direct deposit queue.
     * @param _sender direct deposit sender.
     * @param _amount direct deposit amount in zkBOB units.
     */
    function recordDirectDeposit(address _sender, uint256 _amount) external {
        require(msg.sender == address(direct_deposit_queue), "ZkBobPool: not authorized");
        IZkBobAccounting acc = accounting;
        if (address(acc) != address(0)) {
            acc.recordOperation(IZkBobAccounting.TxType.DirectDeposit, _sender, int256(_amount));
        }
    }

    /**
     * @dev Withdraws accumulated fee on behalf of an operator.
     * Callable only by the operator itself, or by a pre-configured operator fee receiver address.
     * @param _operator address of an operator account to withdraw fee from.
     * @param _to address of the accumulated fee tokens receiver.
     */
    function withdrawFee(address _operator, address _to) external {
        require(
            _operator == msg.sender || operatorManager.isOperatorFeeReceiver(_operator, msg.sender),
            "ZkBobPool: not authorized"
        );
        uint256 fee = accumulatedFee[_operator] * TOKEN_DENOMINATOR / TOKEN_NUMERATOR;
        require(fee > 0, "ZkBobPool: no fee to withdraw");
        IERC20(token).safeTransfer(_to, fee);
        accumulatedFee[_operator] = 0;
        emit WithdrawFee(_operator, fee);
    }

    /**
     * @dev Calculates forced exit operation hash.
     * @param _operator operator address.
     * @param _to withdrawn funds receiver.
     * @param _amount total account balance to withdraw.
     * @param _exitStart exit window start timestamp, should match one calculated in commitForcedExit.
     * @param _exitEnd exit window end timestamp, should match one calculated in commitForcedExit.
     * @return operation hash.
     */
    function _hashForcedExit(
        address _operator,
        address _to,
        uint256 _amount,
        uint256 _exitStart,
        uint256 _exitEnd
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_operator, _to, _amount, _exitStart, _exitEnd));
    }

    /**
     * @dev Tells if caller is the contract owner.
     * Gives ownership rights to the proxy admin as well.
     * @return true, if caller is the contract owner or proxy admin.
     */
    function _isOwner() internal view override returns (bool) {
        return super._isOwner() || _admin() == _msgSender();
    }

    /**
     * @dev Appends a commitment to the pending commitments queue.
     */
    function _appendCommitment(uint256 _commitment, uint64 _fee, address _prover) internal {
        pendingCommitments.pushBack(
            PendingCommitment({commitment: _commitment, fee: _fee, prover: _prover, timestamp: uint64(block.timestamp)})
        );
    }

    /**
     * @dev Validates either the grace period has passed or the caller
     * is the prover who submitted this commitment.
     */
    function _validateGracePeriod(uint64 commitmentTimestamp, address privilegedProver) internal view {
        // We calculate the beggining of the grace period either from the timestamp of the last tree update,
        // or from the timestamp of the commitment, whichever is greater.
        uint64 timestamp = commitmentTimestamp;
        if (timestamp < lastTreeUpdateTimestamp) {
            timestamp = lastTreeUpdateTimestamp;
        }
        require(
            block.timestamp > timestamp + gracePeriod || msg.sender == privilegedProver,
            "ZkBobPool: prover is not allowed to submit the proof yet"
        );
    }
}
