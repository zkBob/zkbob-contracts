// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../interfaces/IZkBobDirectDeposits.sol";
import "../../interfaces/IERC677.sol";
import "../../interfaces/IERC20Permit.sol";
import "../../interfaces/IPolygonPermit.sol";
import "../../interfaces/IPermit2.sol";

/**
 * @title ZkBobPay
 */
contract ZkBobPay {
    using SafeERC20 for IERC20;

    event Pay(uint256 indexed id, address indexed sender, bytes receiver, uint256 amount, address inToken, bytes note);

    error InvalidToken();
    error SwapFailed();
    error InsufficientAmount();
    error Unauthorized();
    error InvalidPermit();

    address public immutable token;
    IZkBobDirectDeposits public immutable queue;
    IPermit2 public immutable permit2;
    address public immutable oneInchRouter;
    address public immutable feeReceiver;

    constructor(address _token, address _queue, address _permit2, address _oneInchRouter, address _feeReceiver) {
        token = _token;
        queue = IZkBobDirectDeposits(_queue);
        permit2 = IPermit2(_permit2);
        oneInchRouter = _oneInchRouter;
        feeReceiver = _feeReceiver;
    }

    function onTokenTransfer(address _from, uint256 _amount, bytes memory _data) external returns (bool) {
        (bytes memory zkAddress, bytes memory note) = abi.decode(_data, (bytes, bytes));
        uint256 id = queue.directDepositNonce();
        IERC677(token).transferAndCall(address(queue), _amount, abi.encode(_from, zkAddress));

        emit Pay(id, _from, zkAddress, _amount, address(token), note);

        return true;
    }

    function pay(
        bytes memory _zkAddress,
        address _inToken,
        uint256 _inAmount,
        uint256 _depositAmount,
        bytes memory _permit,
        bytes memory _oneInchData,
        bytes memory _note
    )
        external
        payable
    {
        if ((msg.value == 0) == (_inToken == address(0))) {
            revert InvalidToken();
        }

        if (msg.value == 0) {
            _transferFromByPermit(_inToken, msg.sender, _inAmount, _permit);

            IERC20(_inToken).approve(oneInchRouter, _inAmount);
        }

        uint256 balance = IERC20(token).balanceOf(address(this));
        (bool status,) = oneInchRouter.call{value: msg.value}(_oneInchData);
        if (!status) {
            revert SwapFailed();
        }

        if (IERC20(token).balanceOf(address(this)) < balance + _depositAmount) {
            revert InsufficientAmount();
        }

        uint256 id = queue.directDepositNonce();
        IERC677(token).transferAndCall(address(queue), _depositAmount, abi.encode(msg.sender, _zkAddress));

        emit Pay(id, msg.sender, _zkAddress, _depositAmount, _inToken, _note);
    }

    function collect(address[] calldata _tokens) external {
        if (msg.sender != feeReceiver) {
            revert Unauthorized();
        }

        for (uint256 i = 0; i < _tokens.length; i++) {
            if (_tokens[i] == address(0)) {
                payable(msg.sender).transfer(address(this).balance);
            } else {
                IERC20(_tokens[i]).safeTransfer(msg.sender, IERC20(_tokens[i]).balanceOf(address(this)));
            }
        }
    }

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
                IPolygonPermit(_token).transferWithAuthorization(
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
