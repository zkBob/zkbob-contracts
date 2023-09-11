// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../interfaces/IZkBobDirectDeposits.sol";
import "../../interfaces/IERC677.sol";
import "../../interfaces/IERC20Permit.sol";
import "../../interfaces/IUSDCPermit.sol";
import "../../interfaces/IPermit2.sol";
import "../../proxy/EIP1967Admin.sol";

/**
 * @title ZkBobPay
 */
contract ZkBobPay is EIP1967Admin {
    using SafeERC20 for IERC20;

    event UpdateFeeReceiver(address receiver);
    event UpdateRouter(address router, bytes4[] selectors, bool enabled);
    event Pay(uint256 indexed id, address indexed sender, bytes receiver, uint256 amount, address inToken, bytes note);

    error InvalidToken();
    error SwapFailed();
    error InsufficientAmount();
    error Unauthorized();
    error InvalidPermit();

    address public immutable token;
    IZkBobDirectDeposits public immutable queue;
    IPermit2 public immutable permit2;

    mapping(address => mapping(bytes4 => bool)) public enabledRouter;
    address public feeReceiver;

    constructor(address _token, address _queue, address _permit2) {
        token = _token;
        queue = IZkBobDirectDeposits(_queue);
        permit2 = IPermit2(_permit2);
    }

    function initialize() external {
        if (msg.sender != address(this)) {
            revert Unauthorized();
        }

        IERC20(token).approve(address(queue), type(uint256).max);
    }

    function onTokenTransfer(address _from, uint256 _amount, bytes memory _data) external returns (bool) {
        if (msg.sender != token) {
            revert Unauthorized();
        }

        (bytes memory zkAddress, bytes memory note) = abi.decode(_data, (bytes, bytes));
        uint256 id = queue.directDeposit(_from, _amount, zkAddress);

        emit Pay(id, _from, zkAddress, _amount, address(token), note);

        return true;
    }

    /**
     * @dev Makes a payment via zkBob Direct Deposit interface.
     * @param _zkAddress receiver zk address in one of the supported formats.
     * @param _inToken input token. Can be different from zkBob pool token. address(0) for native coin.
     * @param _inAmount input token amount.
     * @param _depositAmount zkBob deposit amount, inclusive of direct deposit fee.
     * @param _permit input token approval permit, in one of the supported formats.
     * @param _router router contract address, should be whitelisted by contract admin first.
     * @param _routerData router swap calldata.
     * @param _note optional payment-specific note for the receiver.
     */
    function pay(
        bytes calldata _zkAddress,
        address _inToken,
        uint256 _inAmount,
        uint256 _depositAmount,
        bytes memory _permit,
        address _router,
        bytes calldata _routerData,
        bytes calldata _note
    )
        external
        payable
    {
        if ((msg.value == 0) == (_inToken == address(0))) {
            revert InvalidToken();
        }

        if (_inToken != address(0)) {
            _transferFromByPermit(_inToken, msg.sender, _inAmount, _permit);
        }

        if (_inToken == token) {
            if (_inAmount < _depositAmount) {
                revert InsufficientAmount();
            }
        } else {
            if (!enabledRouter[_router][bytes4(_routerData[:4])]) {
                revert Unauthorized();
            }

            uint256 balance = IERC20(token).balanceOf(address(this));

            if (_inToken != address(0)) {
                IERC20(_inToken).approve(_router, _inAmount);
            }

            (bool status,) = _router.call{value: msg.value}(_routerData);
            if (!status) {
                revert SwapFailed();
            }

            if (IERC20(token).balanceOf(address(this)) < balance + _depositAmount) {
                revert InsufficientAmount();
            }
        }

        uint256 id = queue.directDeposit(msg.sender, _depositAmount, _zkAddress);

        emit Pay(id, msg.sender, _zkAddress, _depositAmount, _inToken, _note);
    }

    function collect(address[] calldata _tokens) external {
        if (msg.sender != feeReceiver) {
            revert Unauthorized();
        }

        for (uint256 i = 0; i < _tokens.length; ++i) {
            if (_tokens[i] == address(0)) {
                payable(msg.sender).transfer(address(this).balance);
            } else {
                IERC20(_tokens[i]).safeTransfer(msg.sender, IERC20(_tokens[i]).balanceOf(address(this)));
            }
        }
    }

    function updateRouter(address _router, bytes4[] calldata _selectors, bool _enabled) external {
        if (msg.sender != _admin()) {
            revert Unauthorized();
        }

        for (uint256 i = 0; i < _selectors.length; ++i) {
            enabledRouter[_router][_selectors[i]] = _enabled;
        }

        emit UpdateRouter(_router, _selectors, _enabled);
    }

    function updateFeeReceiver(address _receiver) external {
        if (msg.sender != feeReceiver && msg.sender != _admin()) {
            revert Unauthorized();
        }

        feeReceiver = _receiver;

        emit UpdateFeeReceiver(_receiver);
    }

    /**
     * @dev Internal function for input token transfer from user account, using a permit.
     * @param _token token address to transfer from the user account.
     * @param _from user address.
     * @param _amount amount of tokens to transfer.
     * @param _permit optional permit data.
     * Empty for regular IERC20.transferFrom.
     * abi.encode(0, deadline, r, (v << 255) | s) for EIP2612 permit.
     * abi.encode(nonce, deadline, r, (v << 255) | s) for USDC auth-like permit, with nonce < 1<<248.
     * abi.encode(nonce, deadline, r, (v << 255) | s) for Permit2-like permit, with 1<<248 <= nonce < 2 * 1<<248.
     */
    function _transferFromByPermit(address _token, address _from, uint256 _amount, bytes memory _permit) internal {
        if (_permit.length == 0) {
            IERC20(_token).safeTransferFrom(_from, address(this), _amount);
        } else if (_permit.length == 128) {
            (uint256 nonce, uint256 deadline, bytes32 r, bytes32 vs) =
                abi.decode(_permit, (uint256, uint256, bytes32, bytes32));
            bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            uint8 v = uint8((uint256(vs) >> 255) + 27);

            if (nonce == 0) {
                IERC20Permit(_token).permit(_from, address(this), _amount, deadline, v, r, s);
                IERC20(_token).safeTransferFrom(_from, address(this), _amount);
            } else if (nonce < 2 ** 248) {
                IUSDCPermit(_token).transferWithAuthorization(
                    _from, address(this), _amount, 0, deadline, bytes32(nonce), v, r, s
                );
            } else if (nonce < 2 ** 249) {
                permit2.permitTransferFrom(
                    IPermit2.PermitTransferFrom({
                        permitted: IPermit2.TokenPermissions({token: _token, amount: _amount}),
                        nonce: nonce,
                        deadline: deadline
                    }),
                    IPermit2.SignatureTransferDetails({to: address(this), requestedAmount: _amount}),
                    _from,
                    abi.encodePacked(r, s, v)
                );
            } else {
                revert InvalidPermit();
            }
        } else {
            revert InvalidPermit();
        }
    }
}
