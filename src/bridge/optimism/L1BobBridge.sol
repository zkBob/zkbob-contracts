// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";
import "../../interfaces/IMintableERC20.sol";
import "../../interfaces/IBurnableERC20.sol";
import "./interfaces/IL1ERC20Bridge.sol";
import "./interfaces/IL2ERC20Bridge.sol";
import "./libraries/CrossDomainEnabled.sol";

/**
 * @title L1BobBridge
 */
contract L1BobBridge is IL1ERC20Bridge, CrossDomainEnabled {
    address public immutable l2TokenBridge;
    address public immutable l1Token;
    address public immutable l2Token;

    constructor(
        address _l1Messenger,
        address _l2TokenBridge,
        address _l1Token,
        address _l2Token
    )
        CrossDomainEnabled(_l1Messenger)
    {
        l2TokenBridge = _l2TokenBridge;
        l1Token = _l1Token;
        l2Token = _l2Token;
    }

    /**
     * @dev Modifier requiring sender to be EOA.  This check could be bypassed by a malicious
     *  contract via initcode, but it takes care of the user error we want to avoid.
     */
    modifier onlyEOA() {
        // Used to stop deposits from contracts (avoid accidentally lost tokens)
        require(!Address.isContract(msg.sender), "Account not EOA");
        _;
    }

    /**
     * @inheritdoc IL1ERC20Bridge
     */
    function depositERC20(
        address _l1Token,
        address _l2Token,
        uint256 _amount,
        uint32 _l2Gas,
        bytes calldata _data
    )
        external
        virtual
        onlyEOA
    {
        _initiateERC20Deposit(_l1Token, _l2Token, msg.sender, msg.sender, _amount, _l2Gas, _data);
    }

    /**
     * @inheritdoc IL1ERC20Bridge
     */
    function depositERC20To(
        address _l1Token,
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32 _l2Gas,
        bytes calldata _data
    )
        external
        virtual
    {
        _initiateERC20Deposit(_l1Token, _l2Token, msg.sender, _to, _amount, _l2Gas, _data);
    }

    /**
     * @dev Performs the logic for deposits by informing the L2 Deposited Token
     * contract of the deposit and calling a handler to lock the L1 funds. (e.g. transferFrom)
     *
     * @param _l1Token Address of the L1 ERC20 we are depositing
     * @param _l2Token Address of the L1 respective L2 ERC20
     * @param _from Account to pull the deposit from on L1
     * @param _to Account to give the deposit to on L2
     * @param _amount Amount of the ERC20 to deposit.
     * @param _l2Gas Gas limit required to complete the deposit on L2.
     * @param _data Optional data to forward to L2. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function _initiateERC20Deposit(
        address _l1Token,
        address _l2Token,
        address _from,
        address _to,
        uint256 _amount,
        uint32 _l2Gas,
        bytes calldata _data
    )
        internal
    {
        require(_l1Token == l1Token, "L1BobBridge: invalid l1Token");
        require(_l2Token == l2Token, "L1BobBridge: invalid l2Token");

        IBurnableERC20(_l1Token).burnFrom(_from, _amount);

        // Construct calldata for _l2Token.finalizeDeposit(_to, _amount)
        bytes memory message = abi.encodeWithSelector(
            IL2ERC20Bridge.finalizeDeposit.selector, _l1Token, _l2Token, _from, _to, _amount, _data
        );

        // Send calldata into L2
        sendCrossDomainMessage(l2TokenBridge, _l2Gas, message);

        emit ERC20DepositInitiated(_l1Token, _l2Token, _from, _to, _amount, _data);
    }

    /**
     * @inheritdoc IL1ERC20Bridge
     */
    function finalizeERC20Withdrawal(
        address _l1Token,
        address _l2Token,
        address _from,
        address _to,
        uint256 _amount,
        bytes calldata _data
    )
        external
        onlyFromCrossDomainAccount(l2TokenBridge)
    {
        require(_l1Token == l1Token, "L1BobBridge: invalid l1Token");
        require(_l2Token == l2Token, "L1BobBridge: invalid l2Token");

        IMintableERC20(_l1Token).mint(_to, _amount);

        emit ERC20WithdrawalFinalized(_l1Token, _l2Token, _from, _to, _amount, _data);
    }
}
