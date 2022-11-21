// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";
import "../../interfaces/IMintableERC20.sol";
import "../../interfaces/IBurnableERC20.sol";
import "./interfaces/IL1ERC20Bridge.sol";
import "./interfaces/IL2ERC20Bridge.sol";
import "./libraries/CrossDomainEnabled.sol";

/**
 * @title L2BobBridge
 */
contract L2BobBridge is IL2ERC20Bridge, CrossDomainEnabled {
    address public immutable l1TokenBridge;
    address public immutable l1Token;
    address public immutable l2Token;

    constructor(
        address _l2Messenger,
        address _l1TokenBridge,
        address _l1Token,
        address _l2Token
    )
        CrossDomainEnabled(_l2Messenger)
    {
        l1TokenBridge = _l1TokenBridge;
        l1Token = _l1Token;
        l2Token = _l2Token;
    }

    /**
     * @inheritdoc IL2ERC20Bridge
     */
    function withdraw(address _l2Token, uint256 _amount, uint32 _l1Gas, bytes calldata _data) external virtual {
        _initiateWithdrawal(_l2Token, msg.sender, msg.sender, _amount, _l1Gas, _data);
    }

    /**
     * @inheritdoc IL2ERC20Bridge
     */
    function withdrawTo(
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32 _l1Gas,
        bytes calldata _data
    )
        external
        virtual
    {
        _initiateWithdrawal(_l2Token, msg.sender, _to, _amount, _l1Gas, _data);
    }

    /**
     * @dev Performs the logic for withdrawals by burning the token and informing
     *      the L1 token Gateway of the withdrawal.
     * @param _l2Token Address of L2 token where withdrawal is initiated.
     * @param _from Account to pull the withdrawal from on L2.
     * @param _to Account to give the withdrawal to on L1.
     * @param _amount Amount of the token to withdraw.
     * @param _l1Gas Unused, but included for potential forward compatibility considerations.
     * @param _data Optional data to forward to L1. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function _initiateWithdrawal(
        address _l2Token,
        address _from,
        address _to,
        uint256 _amount,
        uint32 _l1Gas,
        bytes calldata _data
    )
        internal
    {
        require(_l2Token == l2Token, "L2BobBridge: invalid l2Token");

        IBurnableERC20(_l2Token).burnFrom(msg.sender, _amount);

        bytes memory message = abi.encodeWithSelector(
            IL1ERC20Bridge.finalizeERC20Withdrawal.selector, l1Token, _l2Token, _from, _to, _amount, _data
        );

        // Send message up to L1 bridge
        sendCrossDomainMessage(l1TokenBridge, _l1Gas, message);

        emit WithdrawalInitiated(l1Token, _l2Token, msg.sender, _to, _amount, _data);
    }

    /**
     * @inheritdoc IL2ERC20Bridge
     */
    function finalizeDeposit(
        address _l1Token,
        address _l2Token,
        address _from,
        address _to,
        uint256 _amount,
        bytes calldata _data
    )
        external
        virtual
        onlyFromCrossDomainAccount(l1TokenBridge)
    {
        require(_l1Token == l1Token, "L2BobBridge: invalid l1Token");
        require(_l2Token == l2Token, "L2BobBridge: invalid l2Token");

        IMintableERC20(_l2Token).mint(_to, _amount);

        emit DepositFinalized(_l1Token, _l2Token, _from, _to, _amount, _data);
    }
}
