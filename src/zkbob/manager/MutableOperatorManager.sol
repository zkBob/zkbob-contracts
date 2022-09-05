// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../interfaces/IOperatorManager.sol";
import "../../utils/Ownable.sol";

/**
 * @title MutableOperatorManager
 * @dev Implements a mutable access control for ZkBobPool relayers.
 */
contract MutableOperatorManager is IOperatorManager, Ownable {
    // current operator address
    address public operator;
    // mapping of all historical fee receiver addresses, we keep fee receivers addresses
    // in a mapping to allow fee withdrawals even after operator address was changed
    mapping(address => address) public operatorFeeReceiver;
    // current operator public API URL
    string public operatorURI;

    constructor(address _operator, address _feeReceiver, string memory _operatorURI) Ownable() {
        _setOperator(_operator, _feeReceiver, _operatorURI);
    }

    function setOperator(address _operator, address _feeReceiver, string memory _endpoint) external onlyOwner {
        _setOperator(_operator, _feeReceiver, _endpoint);
    }

    function _setOperator(address _operator, address _feeReceiver, string memory _operatorURI) internal {
        require(_operator != address(0), "OperatorManager: empty operator");
        require(_feeReceiver != address(0), "OperatorManager: empty fee receiver");
        require(bytes(_operatorURI).length > 0, "OperatorManager: empty uri");
        operator = _operator;
        operatorURI = _operatorURI;
        operatorFeeReceiver[_operator] = _feeReceiver;
    }

    function isOperator(address _addr) external view override returns (bool) {
        return operator == _addr;
    }

    function isOperatorFeeReceiver(address _operator, address _addr) external view override returns (bool) {
        return operatorFeeReceiver[_operator] == _addr;
    }
}
