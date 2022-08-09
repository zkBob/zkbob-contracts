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
import "./utils/ZkBobPoolStats.sol";
import "../utils/Ownable.sol";
import "../proxy/EIP1967Admin.sol";

contract ZkBobPool is EIP1967Admin, Ownable, Parameters, ZkBobPoolStats {
    using SafeERC20 for IERC20;

    uint256 internal constant MAX_POOL_ID = 0xffffff;

    uint256 public immutable pool_id;
    uint256 public immutable denominator;
    uint256 public immutable native_denominator;
    ITransferVerifier public immutable transfer_verifier;
    ITreeVerifier public immutable tree_verifier;
    address public immutable token;

    IOperatorManager public operatorManager;

    address public xpToken;
    uint96 public xpDenominator;

    mapping(uint256 => uint256) public nullifiers;
    mapping(uint256 => uint256) public roots;
    uint256 public pool_index;
    bytes32 public all_messages_hash;

    event Message(uint256 indexed index, bytes32 indexed hash, bytes message);

    constructor(
        uint256 __pool_id,
        address _token,
        uint256 _denominator,
        uint256 _native_denominator,
        ITransferVerifier _transfer_verifier,
        ITreeVerifier _tree_verifier
    ) {
        require(__pool_id <= MAX_POOL_ID);
        pool_id = __pool_id;
        token = _token;
        denominator = _denominator;
        native_denominator = _native_denominator;
        transfer_verifier = _transfer_verifier;
        tree_verifier = _tree_verifier;
    }

    modifier onlyOperator() {
        require(operatorManager.isOperator(_msgSender()), "ZkBobPool: not an operator");
        _;
    }

    function initialize(uint256 _root) external {
        require(msg.sender == address(this), "ZkBobPool: not initializer");
        require(roots[0] == 0, "ZkBobPool: already initialized");
        roots[0] = _root;
    }

    function setOperatorManager(IOperatorManager _operatorManager) external onlyOwner {
        operatorManager = _operatorManager;
    }

    function _root() internal view override returns (uint256) {
        return roots[_transfer_index()];
    }

    function _pool_id() internal view override returns (uint256) {
        return pool_id;
    }

    function _tvl() internal view override returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function transact() external payable onlyOperator {
        (uint56 weekMaxTvl, uint32 weekCount, uint256 poolIndex) = _updateStats();

        uint256 nullifier = _transfer_nullifier();
        {
            require(transfer_verifier.verifyProof(_transfer_pub(), _transfer_proof()), "ZkBobPool: bad transfer proof");
            require(nullifiers[nullifier] == 0, "ZkBobPool: doublespend detected");
            require(_transfer_index() <= poolIndex, "ZkBobPool: transfer index out of bounds");
            require(tree_verifier.verifyProof(_tree_pub(roots[poolIndex]), _tree_proof()), "ZkBobPool: bad tree proof");

            nullifiers[nullifier] = uint256(keccak256(abi.encodePacked(_transfer_out_commit(), _transfer_delta())));
            poolIndex += 128;
            roots[poolIndex] = _tree_root_after();
            bytes memory message = _memo_message();
            bytes32 message_hash = keccak256(message);
            bytes32 _all_messages_hash = keccak256(abi.encodePacked(all_messages_hash, message_hash));
            all_messages_hash = _all_messages_hash;
            emit Message(poolIndex, _all_messages_hash, message);
        }

        uint256 fee = _memo_fee();
        int256 token_amount = _transfer_token_amount() + int256(fee);
        int256 energy_amount = _transfer_energy_amount();

        if (_tx_type() == 0) {
            // Deposit
            require(token_amount >= 0 && energy_amount == 0 && msg.value == 0, "ZkBobPool: incorrect deposit amounts");
            IERC20(token).safeTransferFrom(_deposit_spender(), address(this), uint256(token_amount) * denominator);
        } else if (_tx_type() == 1) {
            // Transfer
            require(token_amount == 0 && energy_amount == 0 && msg.value == 0, "ZkBobPool: incorrect transfer amounts");
        } else if (_tx_type() == 2) {
            // Withdraw
            require(
                token_amount <= 0 && energy_amount <= 0 && msg.value == _memo_native_amount() * native_denominator,
                "ZkBobPool: incorrect withdraw amounts"
            );

            address receiver = _memo_receiver();

            if (token_amount < 0) {
                IERC20(token).safeTransfer(receiver, uint256(-token_amount) * denominator);
            }

            if (energy_amount < 0) {
                require(xpToken != address(0), "ZkBobPool: XP claiming is not enabled");
                uint256 xpAmount = uint256(-energy_amount) * xpDenominator / 1 ether;
                IMintableERC20(xpToken).mint(receiver, xpAmount);
            }

            if (msg.value > 0) {
                // TODO safe send via Sacrifice ?
                (bool success,) = payable(receiver).call{value: msg.value}("");
                require(success);
            }
        } else if (_tx_type() == 3) {
            // Permittable token deposit
            require(token_amount >= 0 && energy_amount == 0 && msg.value == 0, "ZkBobPool: incorrect deposit amounts");
            (uint8 v, bytes32 r, bytes32 s) = _permittable_deposit_signature();
            address holder = _memo_permit_holder();
            uint256 amount = uint256(token_amount) * denominator;
            IERC20Permit(token).receiveWithSaltedPermit(
                holder, amount, _memo_permit_deadline(), bytes32(nullifier), v, r, s
            );
        } else {
            revert("ZkBobPool: Incorrect transaction type");
        }

        if (fee > 0) {
            IERC20(token).safeTransfer(msg.sender, fee * denominator);
        }
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
