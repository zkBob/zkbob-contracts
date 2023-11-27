// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../interfaces/IOperatorManager.sol";
import "../../utils/Ownable.sol";

/**
 * @title AllowListOperatorManager
 * @dev Implements a allow list based access control for ZkBobPool relayers.
 */
contract AllowListOperatorManager is IOperatorManager, Ownable {
    // if true, only whitelisted addresses can be operators
    // if false, anyone can be an operator
    bool public allowListEnabled;
    
    // mapping of whitelisted operator addresses
    mapping(address => bool) public operators;

    // mapping of all historical fee receiver addresses, we keep fee receivers addresses
    // in a mapping to allow fee withdrawals even after operator address was changed
    mapping(address => address) public operatorFeeReceiver;

    event UpdateOperator(address indexed operator, address feeReceiver, bool allowed);
    event UpdateAllowListEnabled(bool enabled);

    modifier nonZeroAddress(address addr) {
        require(addr != address(0), "WhitelistBasedOperatorManager: zero address");
        _;
    }

    constructor(
        address[] memory _operators, 
        bool[] memory _allowed, 
        address[] memory _feeReceivers, 
        bool _whitelistEnabled
    ) Ownable() {
        allowListEnabled = _whitelistEnabled;
        _setOperators(_operators, _allowed, _feeReceivers);
    }
    
    function operatorURI() external pure returns (string memory) {
        return "";
    }

    function setAllowListEnabled(bool _allowListEnabled) external onlyOwner {
        allowListEnabled = _allowListEnabled;
        emit UpdateAllowListEnabled(_allowListEnabled);
    }

    function setOperators(
        address[] calldata _operators, 
        bool[] calldata _allowed,
        address[] calldata _feeReceivers
    ) external onlyOwner {
        _setOperators(_operators, _allowed, _feeReceivers);
    }

    function setOperator(
        address _operator, 
        address _feeReceiver, 
        bool _allowed
    ) external onlyOwner {
        _setOperator(_operator, _allowed, _feeReceiver);
    }

    function _setOperators(
        address[] memory _operators, 
        bool[] memory _allowed,
        address[] memory _feeReceivers
    ) internal {
        require(_operators.length == _feeReceivers.length, "WhitelistBasedOperatorManager: arrays length mismatch");
        require(_operators.length == _allowed.length, "WhitelistBasedOperatorManager: arrays length mismatch");
        
        for (uint256 i = 0; i < _operators.length; i++) {
            _setOperator(_operators[i], _allowed[i], _feeReceivers[i]);
        }
    }

    function _setOperator(
        address _operator, 
        bool _allowed,
        address _feeReceiver
    ) nonZeroAddress(_operator) internal {
        operators[_operator] = _allowed;
        if (_feeReceiver != address(0) && _allowed) {
            operatorFeeReceiver[_operator] = _feeReceiver;
        }
        emit UpdateOperator(_operator, _feeReceiver, _allowed);
    }

    function isOperator(address _addr) external view override returns (bool) {
        return operators[_addr] || !allowListEnabled;
    }

    function isOperatorFeeReceiver(address _operator, address _addr) external view override returns (bool) {
        return operatorFeeReceiver[_operator] == _addr;
    }
}
