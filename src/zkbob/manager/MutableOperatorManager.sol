// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../interfaces/IOperatorManager.sol";
import "../../utils/Ownable.sol";

contract MutableOperatorManager is IOperatorManager, Ownable {
    address public operator;
    mapping(address => address) public operatorFeeReceiver;
    string public operatorURI;

    constructor(address _operator, address _feeReceiver, string memory _operatorURI) Ownable() {
        _setOperator(_operator, _feeReceiver, _operatorURI);
    }

    function setOperator(address _operator, address _feeReceiver, string memory _endpoint) external onlyOwner {
        _setOperator(_operator, _feeReceiver, _endpoint);
    }

    function _setOperator(address _operator, address _feeReceiver, string memory _operatorURI) internal {
        if (_operator == address(0)) {
            require(_feeReceiver == address(0), "OperatorManager: Non-zero fee receiver");
            require(bytes(_operatorURI).length == 0, "OperatorManager: non-empty uri");
        } else {
            require(bytes(_operatorURI).length > 0, "OperatorManager: empty uri");
            operatorFeeReceiver[_operator] = _feeReceiver;
        }
        operator = _operator;
        operatorURI = _operatorURI;
    }

    function isOperator(address _addr) external view override returns (bool) {
        return operator == _addr || operator == address(0);
    }

    function isOperatorFeeReceiver(address _operator, address _addr) external view override returns (bool) {
        return operatorFeeReceiver[_operator] == _addr;
    }
}
