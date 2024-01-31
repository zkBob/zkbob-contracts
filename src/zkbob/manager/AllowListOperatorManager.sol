// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import {IOperatorManager} from "../../interfaces/IOperatorManager.sol";
import {Ownable} from "../../utils/Ownable.sol";

/**
 * @title AllowListOperatorManager
 * @dev Implements an allow list based access control for ZkBobPool relayers.
 */
contract AllowListOperatorManager is IOperatorManager, Ownable {
    // if true, only whitelisted addresses can be operators
    // if false, anyone can be an operator
    bool public allowListEnabled;

    // mapping of whitelisted operator addresses
    mapping(address => bool) public operators;

    // mapping of fee receivers for operators
    mapping(address => address) public operatorFeeReceiver;

    event UpdateOperator(address indexed operator, address feeReceiver, bool allowed);
    event UpdateAllowListEnabled(bool enabled);

    modifier nonZeroAddress(address addr) {
        require(addr != address(0), "OperatorManager: zero address");
        _;
    }

    constructor(address[] memory _operators, address[] memory _feeReceivers, bool _allowListEnabled) Ownable() {
        require(_operators.length == _feeReceivers.length, "OperatorManager: arrays length mismatch");
        
        allowListEnabled = _allowListEnabled;
        for (uint256 i = 0; i < _operators.length; i++) {
            _setOperator(_operators[i], true, _feeReceivers[i]);
        }
    }

    /**
     * @dev Doesn't return any data, as operator URI is not used in this implementation.
     */
    function operatorURI() external pure returns (string memory) {
        return "";
    }

    /**
     * @dev Sets the allow list enabled flag.
     * @param _allowListEnabled flag to enable or disable allow list.
     */
    function setAllowListEnabled(bool _allowListEnabled) external onlyOwner {
        allowListEnabled = _allowListEnabled;
        emit UpdateAllowListEnabled(_allowListEnabled);
    }

    /**
     * @dev Adds or removes an operator from the allow list.
     * @param _operator address of the operator.
     * @param _allowed flag to enable or disable operator.
     * @param _feeReceiver address of the fee receiver.
     */
    function setOperator(address _operator, address _feeReceiver, bool _allowed) external onlyOwner {
        _setOperator(_operator, _allowed, _feeReceiver);
    }

    /**
     * @dev Adds or removes operators from the allow list.
     * @param _operators addresses of the operators.
     * @param _allowed flags to enable or disable operators.
     * @param _feeReceivers addresses of the fee receivers.
     */
    function setOperators(
        address[] calldata _operators,
        bool[] calldata _allowed,
        address[] calldata _feeReceivers
    )
        external
        onlyOwner
    {
        require(_operators.length == _feeReceivers.length, "OperatorManager: arrays length mismatch");
        require(_operators.length == _allowed.length, "OperatorManager: arrays length mismatch");

        for (uint256 i = 0; i < _operators.length; i++) {
            _setOperator(_operators[i], _allowed[i], _feeReceivers[i]);
        }
    }

    /**
     * @dev Sets the fee receiver for the operator.
     * @param _feeReceiver address of the fee receiver.
     */
    function setFeeReceiver(address _feeReceiver) external {
        require(isOperator(msg.sender), "OperatorManager: operator not allowed");
        operatorFeeReceiver[msg.sender] = _feeReceiver;
        emit UpdateOperator(msg.sender, _feeReceiver, true);
    }

    function _setOperator(address _operator, bool _allowed, address _feeReceiver) internal nonZeroAddress(_operator) {
        operators[_operator] = _allowed;
        if (_allowed) {
            operatorFeeReceiver[_operator] = _feeReceiver;
        }
        emit UpdateOperator(_operator, operatorFeeReceiver[_operator], _allowed);
    }

    /**
     * @dev Returns true if the address is an operator.
     * @param _addr address to check.
     */
    function isOperator(address _addr) public view override returns (bool) {
        return operators[_addr] || !allowListEnabled;
    }

    /**
     * @dev Returns true if the address is an operator fee receiver.
     * @param _operator address of the operator.
     * @param _addr address to check.
     */
    function isOperatorFeeReceiver(address _operator, address _addr) external view override returns (bool) {
        return operatorFeeReceiver[_operator] == _addr;
    }
}
