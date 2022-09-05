// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/ITransferVerifier.sol";
import "../interfaces/ITreeVerifier.sol";
import "../interfaces/IMintableERC20.sol";
import "../interfaces/IOperatorManager.sol";
import "../interfaces/IERC20Permit.sol";
import "./utils/Parameters.sol";
import "./utils/ZkBobAccounting.sol";
import "../utils/Ownable.sol";
import "../proxy/EIP1967Admin.sol";

/**
 * @title ZkBobPool
 * Shielded transactions pool for BOB tokens.
 */
contract ZkBobPool is EIP1967Admin, Ownable, Parameters, ZkBobAccounting {
    using SafeERC20 for IERC20;

    uint256 internal constant MAX_POOL_ID = 0xffffff;
    uint256 internal constant TOKEN_DENOMINATOR = 1_000_000_000;
    uint256 internal constant NATIVE_DENOMINATOR = 1_000_000_000;

    uint256 public immutable pool_id;
    ITransferVerifier public immutable transfer_verifier;
    ITreeVerifier public immutable tree_verifier;
    address public immutable token;

    IOperatorManager public operatorManager;

    mapping(uint256 => uint256) public nullifiers;
    mapping(uint256 => uint256) public roots;
    bytes32 public all_messages_hash;

    mapping(address => uint256) public accumulatedFee;

    event Message(uint256 indexed index, bytes32 indexed hash, bytes message);

    constructor(uint256 __pool_id, address _token, ITransferVerifier _transfer_verifier, ITreeVerifier _tree_verifier) {
        require(__pool_id <= MAX_POOL_ID);
        pool_id = __pool_id;
        token = _token;
        transfer_verifier = _transfer_verifier;
        tree_verifier = _tree_verifier;
    }

    modifier onlyOperator() {
        require(operatorManager.isOperator(_msgSender()), "ZkBobPool: not an operator");
        _;
    }

    function initialize(
        uint256 _root,
        uint256 _tvlCap,
        uint256 _dailyDepositCap,
        uint256 _dailyWithdrawalCap,
        uint256 _dailyUserDepositCap,
        uint256 _depositCap
    )
        external
    {
        require(msg.sender == address(this), "ZkBobPool: not initializer");
        require(roots[0] == 0, "ZkBobPool: already initialized");
        roots[0] = _root;
        _setLimits(
            _tvlCap / TOKEN_DENOMINATOR,
            _dailyDepositCap / TOKEN_DENOMINATOR,
            _dailyWithdrawalCap / TOKEN_DENOMINATOR,
            _dailyUserDepositCap / TOKEN_DENOMINATOR,
            _depositCap / TOKEN_DENOMINATOR
        );
    }

    function setOperatorManager(IOperatorManager _operatorManager) external onlyOwner {
        operatorManager = _operatorManager;
    }

    function denominator() external pure returns (uint256) {
        return TOKEN_DENOMINATOR;
    }

    function pool_index() external view returns (uint256) {
        return _txCount() << 7;
    }

    function _root() internal view override returns (uint256) {
        return roots[_transfer_index()];
    }

    function _pool_id() internal view override returns (uint256) {
        return pool_id;
    }

    function transact() external payable onlyOperator {
        address user;
        uint256 txType = _tx_type();
        if (txType == 0) {
            user = _deposit_spender();
        } else if (txType == 3) {
            user = _memo_permit_holder();
        }
        (,, uint256 txCount) = _recordOperation(user, _transfer_token_amount());

        uint256 nullifier = _transfer_nullifier();
        {
            uint256 _pool_index = txCount << 7;

            require(nullifiers[nullifier] == 0, "ZkBobPool: doublespend detected");
            require(_transfer_index() <= _pool_index, "ZkBobPool: transfer index out of bounds");
            require(transfer_verifier.verifyProof(_transfer_pub(), _transfer_proof()), "ZkBobPool: bad transfer proof");
            require(
                tree_verifier.verifyProof(_tree_pub(roots[_pool_index]), _tree_proof()), "ZkBobPool: bad tree proof"
            );

            nullifiers[nullifier] = uint256(keccak256(abi.encodePacked(_transfer_out_commit(), _transfer_delta())));
            _pool_index += 128;
            roots[_pool_index] = _tree_root_after();
            bytes memory message = _memo_message();
            bytes32 message_hash = keccak256(message);
            bytes32 _all_messages_hash = keccak256(abi.encodePacked(all_messages_hash, message_hash));
            all_messages_hash = _all_messages_hash;
            emit Message(_pool_index, _all_messages_hash, message);
        }

        uint256 fee = _memo_fee();
        int256 token_amount = _transfer_token_amount() + int256(fee);
        int256 energy_amount = _transfer_energy_amount();

        if (txType == 0) {
            // Deposit
            require(token_amount >= 0 && energy_amount == 0 && msg.value == 0, "ZkBobPool: incorrect deposit amounts");
            IERC20(token).safeTransferFrom(user, address(this), uint256(token_amount) * TOKEN_DENOMINATOR);
        } else if (txType == 1) {
            // Transfer
            require(token_amount == 0 && energy_amount == 0 && msg.value == 0, "ZkBobPool: incorrect transfer amounts");
        } else if (txType == 2) {
            // Withdraw
            require(
                token_amount <= 0 && energy_amount <= 0 && msg.value == _memo_native_amount() * NATIVE_DENOMINATOR,
                "ZkBobPool: incorrect withdraw amounts"
            );

            if (token_amount < 0) {
                IERC20(token).safeTransfer(_memo_receiver(), uint256(-token_amount) * TOKEN_DENOMINATOR);
            }

            // energy withdrawals are not yet implemented, any transaction with non-zero energy_amount will revert
            // future version of the protocol will support energy withdrawals through negative energy_amount
            if (energy_amount < 0) {
                revert("ZkBobPool: XP claiming is not yet enabled");
            }

            if (msg.value > 0) {
                payable(_memo_receiver()).transfer(msg.value);
            }
        } else if (txType == 3) {
            // Permittable token deposit
            require(token_amount >= 0 && energy_amount == 0 && msg.value == 0, "ZkBobPool: incorrect deposit amounts");
            (uint8 v, bytes32 r, bytes32 s) = _permittable_deposit_signature();
            IERC20Permit(token).receiveWithSaltedPermit(
                user, uint256(token_amount) * TOKEN_DENOMINATOR, _memo_permit_deadline(), bytes32(nullifier), v, r, s
            );
        } else {
            revert("ZkBobPool: Incorrect transaction type");
        }

        if (fee > 0) {
            accumulatedFee[msg.sender] += fee;
        }
    }

    function withdrawFee(address _operator, address _to) external {
        require(
            _operator == msg.sender || operatorManager.isOperatorFeeReceiver(_operator, msg.sender),
            "ZkBobPool: not authorized"
        );
        uint256 fee = accumulatedFee[_operator];
        require(fee > 0, "ZkBobPool: no fee to withdraw");
        IERC20(token).safeTransfer(_to, fee * TOKEN_DENOMINATOR);
        accumulatedFee[_operator] = 0;
    }

    function setLimits(
        uint256 _tvlCap,
        uint256 _dailyDepositCap,
        uint256 _dailyWithdrawalCap,
        uint256 _dailyUserDepositCap,
        uint256 _depositCap
    )
        external
        onlyOwner
    {
        _setLimits(
            _tvlCap / TOKEN_DENOMINATOR,
            _dailyDepositCap / TOKEN_DENOMINATOR,
            _dailyWithdrawalCap / TOKEN_DENOMINATOR,
            _dailyUserDepositCap / TOKEN_DENOMINATOR,
            _depositCap / TOKEN_DENOMINATOR
        );
    }

    /**
     * @dev Tells if caller is the contract owner.
     * Gives ownership rights to the proxy admin as well.
     * @return true, if caller is the contract owner or proxy admin.
     */
    function _isOwner() internal view override returns (bool) {
        return super._isOwner() || _admin() == _msgSender();
    }
}
