// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "../libraries/ZkAddress.sol";
import "../interfaces/IOperatorManager.sol";
import "../interfaces/IZkBobDirectDeposits.sol";
import "../interfaces/IZkBobDirectDepositQueue.sol";
import "../interfaces/IZkBobPool.sol";
import "../utils/Ownable.sol";
import "../proxy/EIP1967Admin.sol";

/**
 * @title ZkBobDirectDepositQueue
 * Queue for zkBob direct deposits.
 */
contract ZkBobDirectDepositQueue is IZkBobDirectDeposits, IZkBobDirectDepositQueue, EIP1967Admin, Ownable {
    using SafeERC20 for IERC20;

    uint256 internal constant R = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 internal constant MAX_POOL_ID = 0xffffff;
    uint256 internal constant TOKEN_DENOMINATOR = 1_000_000_000;
    uint256 internal constant MAX_NUMBER_OF_DIRECT_DEPOSITS = 16;
    bytes4 internal constant MESSAGE_PREFIX_DIRECT_DEPOSIT_V1 = 0x00000001;

    address public immutable token;
    uint256 public immutable pool_id;
    address public immutable pool;

    IOperatorManager public operatorManager;

    mapping(uint256 => IZkBobDirectDeposits.DirectDeposit) internal directDeposits;
    uint32 public directDepositNonce;
    uint64 public directDepositFee;
    uint40 public directDepositTimeout;

    event UpdateOperatorManager(address manager);
    event UpdateDirectDepositFee(uint64 fee);
    event UpdateDirectDepositTimeout(uint40 timeout);

    event SubmitDirectDeposit(
        address indexed sender,
        uint256 indexed nonce,
        address fallbackUser,
        ZkAddress.ZkAddress zkAddress,
        uint64 deposit
    );
    event RefundDirectDeposit(uint256 indexed nonce, address receiver, uint256 amount);
    event CompleteDirectDepositBatch(uint256[] indices);

    constructor(address _pool, address _token) {
        require(Address.isContract(_token), "ZkBobDirectDepositQueue: not a contract");
        pool = _pool;
        token = _token;
        pool_id = uint24(IZkBobPool(_pool).pool_id());
    }

    /**
     * @dev Throws if called by any account other than the current relayer operator.
     */
    modifier onlyOperator() {
        require(operatorManager.isOperator(_msgSender()), "ZkBobDirectDepositQueue: not an operator");
        _;
    }

    /**
     * @dev Updates used operator manager contract.
     * Callable only by the contract owner / proxy admin.
     * @param _operatorManager new operator manager implementation.
     */
    function setOperatorManager(IOperatorManager _operatorManager) external onlyOwner {
        require(address(_operatorManager) != address(0), "ZkBobDirectDepositQueue: manager is zero address");
        operatorManager = _operatorManager;
        emit UpdateOperatorManager(address(_operatorManager));
    }

    /**
     * @dev Updates direct deposit fee.
     * Callable only by the contract owner / proxy admin.
     * @param _fee new absolute fee value for making a direct deposit, in zkBOB units.
     */
    function setDirectDepositFee(uint64 _fee) external onlyOwner {
        directDepositFee = _fee;
        emit UpdateDirectDepositFee(_fee);
    }

    /**
     * @dev Updates direct deposit timeout.
     * Callable only by the contract owner / proxy admin.
     * @param _timeout new timeout value for refunding non-fulfilled/rejected direct deposits.
     */
    function setDirectDepositTimeout(uint40 _timeout) external onlyOwner {
        require(_timeout <= 7 days, "ZkBobDirectDepositQueue: timeout too large");
        directDepositTimeout = _timeout;
        emit UpdateDirectDepositTimeout(_timeout);
    }

    /// @inheritdoc IZkBobDirectDeposits
    function getDirectDeposit(uint256 _index) external view returns (IZkBobDirectDeposits.DirectDeposit memory) {
        return directDeposits[_index];
    }

    /// @inheritdoc IZkBobDirectDepositQueue
    function collect(
        uint256[] calldata _indices,
        uint256 _out_commit
    )
        external
        returns (uint256 total, uint256 totalFee, uint256 hashsum, bytes memory message)
    {
        require(msg.sender == pool, "ZkBobDirectDepositQueue: invalid caller");

        uint256 count = _indices.length;
        require(count > 0, "ZkBobDirectDepositQueue: empty deposit list");
        require(count <= MAX_NUMBER_OF_DIRECT_DEPOSITS, "ZkBobDirectDepositQueue: too many deposits");

        bytes memory input = new bytes(32 + (10 + 32 + 8) * MAX_NUMBER_OF_DIRECT_DEPOSITS);
        message = new bytes(4 + count * (8 + 10 + 32 + 8));
        assembly {
            mstore(add(input, 32), _out_commit)
            mstore(add(message, 32), or(shl(248, count), MESSAGE_PREFIX_DIRECT_DEPOSIT_V1))
        }
        total = 0;
        totalFee = 0;
        for (uint256 i = 0; i < count; i++) {
            uint256 index = _indices[i];
            DirectDeposit storage dd = directDeposits[index];
            (bytes32 pk, bytes10 diversifier, uint64 deposit, uint64 fee, DirectDepositStatus status) =
                (dd.pk, dd.diversifier, dd.deposit, dd.fee, dd.status);
            require(status == DirectDepositStatus.Pending, "ZkBobDirectDepositQueue: direct deposit not pending");

            assembly {
                // bytes10(dd.diversifier) ++ bytes32(dd.pk) ++ bytes8(dd.deposit)
                let offset := mul(i, 50)
                mstore(add(input, add(64, offset)), diversifier)
                mstore(add(input, add(82, offset)), deposit)
                mstore(add(input, add(74, offset)), pk)
            }
            assembly {
                // bytes8(dd.index) ++ bytes10(dd.diversifier) ++ bytes32(dd.pk) ++ bytes8(dd.deposit)
                let offset := mul(i, 58)
                mstore(add(message, add(36, offset)), shl(192, index))
                mstore(add(message, add(44, offset)), diversifier)
                mstore(add(message, add(62, offset)), deposit)
                mstore(add(message, add(54, offset)), pk)
            }

            dd.status = DirectDepositStatus.Completed;

            total += deposit;
            totalFee += fee;
        }

        hashsum = uint256(keccak256(input)) % R;

        IERC20(token).safeTransfer(msg.sender, (total + totalFee) * TOKEN_DENOMINATOR);

        emit CompleteDirectDepositBatch(_indices);
    }

    /// @inheritdoc IZkBobDirectDeposits
    function directDeposit(
        address _fallbackUser,
        uint256 _amount,
        string calldata _zkAddress
    )
        external
        returns (uint256)
    {
        return directDeposit(_fallbackUser, _amount, bytes(_zkAddress));
    }

    /// @inheritdoc IZkBobDirectDeposits
    function directDeposit(
        address _fallbackUser,
        uint256 _amount,
        bytes memory _rawZkAddress
    )
        public
        returns (uint256)
    {
        IERC20(token).transferFrom(msg.sender, address(this), _amount);
        return _recordDirectDeposit(msg.sender, _fallbackUser, _amount, _rawZkAddress);
    }

    /// @inheritdoc IZkBobDirectDeposits
    function directNativeDeposit(
        address _fallbackUser,
        string calldata _zkAddress
    )
        external
        payable
        returns (uint256)
    {
        return directNativeDeposit(_fallbackUser, bytes(_zkAddress));
    }

    /// @inheritdoc IZkBobDirectDeposits
    function directNativeDeposit(address _fallbackUser, bytes memory _rawZkAddress) public payable returns (uint256) {
        uint256 amount = msg.value;
        IWETH9(token).deposit{value: amount}();
        return _recordDirectDeposit(msg.sender, _fallbackUser, amount, _rawZkAddress);
    }

    /// @inheritdoc IZkBobDirectDeposits
    function onTokenTransfer(address _from, uint256 _value, bytes calldata _data) external returns (bool) {
        require(msg.sender == token, "ZkBobDirectDepositQueue: not a token caller");

        (address fallbackUser, bytes memory rawZkAddress) = abi.decode(_data, (address, bytes));

        _recordDirectDeposit(_from, fallbackUser, _value, rawZkAddress);

        return true;
    }

    /// @inheritdoc IZkBobDirectDeposits
    function refundDirectDeposit(uint256 _index) external {
        bool isOperator = operatorManager.isOperator(msg.sender);
        DirectDeposit storage dd = directDeposits[_index];
        require(dd.status == DirectDepositStatus.Pending, "ZkBobDirectDepositQueue: direct deposit not pending");
        require(
            isOperator || dd.timestamp + directDepositTimeout < block.timestamp,
            "ZkBobDirectDepositQueue: direct deposit timeout not passed"
        );
        _refundDirectDeposit(_index, dd);
    }

    /// @inheritdoc IZkBobDirectDeposits
    function refundDirectDeposit(uint256[] calldata _indices) external {
        bool isOperator = operatorManager.isOperator(msg.sender);

        for (uint256 i = 0; i < _indices.length; i++) {
            DirectDeposit storage dd = directDeposits[_indices[i]];

            if (dd.status == DirectDepositStatus.Pending) {
                require(
                    isOperator || dd.timestamp + directDepositTimeout < block.timestamp,
                    "ZkBobDirectDepositQueue: direct deposit timeout not passed"
                );
                _refundDirectDeposit(_indices[i], dd);
            }
        }
    }

    function _refundDirectDeposit(uint256 _index, IZkBobDirectDeposits.DirectDeposit storage _dd) internal {
        _dd.status = IZkBobDirectDeposits.DirectDepositStatus.Refunded;

        (address fallbackReceiver, uint96 amount) = (_dd.fallbackReceiver, _dd.sent);

        IERC20(token).safeTransfer(fallbackReceiver, amount);

        emit RefundDirectDeposit(_index, fallbackReceiver, amount);
    }

    function _recordDirectDeposit(
        address _sender,
        address _fallbackReceiver,
        uint256 _amount,
        bytes memory _rawZkAddress
    )
        internal
        returns (uint256 nonce)
    {
        require(_fallbackReceiver != address(0), "ZkBobDirectDepositQueue: fallback user is zero");

        uint64 fee = directDepositFee;
        // small amount of wei might get lost during division, this amount will stay in the contract indefinitely
        uint64 depositAmount = uint64(_amount / TOKEN_DENOMINATOR);
        require(depositAmount > fee, "ZkBobDirectDepositQueue: direct deposit amount is too low");
        unchecked {
            depositAmount -= fee;
        }

        ZkAddress.ZkAddress memory zkAddress = ZkAddress.parseZkAddress(_rawZkAddress, uint24(pool_id));

        IZkBobDirectDeposits.DirectDeposit memory dd = IZkBobDirectDeposits.DirectDeposit({
            fallbackReceiver: _fallbackReceiver,
            sent: uint96(_amount),
            deposit: depositAmount,
            fee: fee,
            timestamp: uint40(block.timestamp),
            status: DirectDepositStatus.Pending,
            diversifier: zkAddress.diversifier,
            pk: zkAddress.pk
        });

        nonce = directDepositNonce++;
        directDeposits[nonce] = dd;

        IZkBobPool(pool).recordDirectDeposit(_sender, depositAmount);

        emit SubmitDirectDeposit(_sender, nonce, _fallbackReceiver, zkAddress, depositAmount);
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
