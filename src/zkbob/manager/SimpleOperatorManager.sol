// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../interfaces/IOperatorManager.sol";

contract SimpleOperatorManager is IOperatorManager {
    address public immutable operator;
    address public immutable operatorFeeReceiver;
    string public operatorURI;

    constructor(address _operator, address _operatorFeeReceiver, string memory _operatorURI) {
        if (_operator == address(0)) {
            require(_operatorFeeReceiver == address(0), "OperatorManager: non-empty fee ");
            require(bytes(_operatorURI).length == 0, "OperatorManager: non-empty uri");
        } else {
            require(bytes(_operatorURI).length > 0, "OperatorManager: empty uri");
        }
        operator = _operator;
        operatorFeeReceiver = _operatorFeeReceiver;
        operatorURI = _operatorURI;
    }

    function isOperator(address _addr) external view override returns (bool) {
        return operator == _addr || operator == address(0);
    }

    function isOperatorFeeReceiver(address _operator, address _addr) external view override returns (bool) {
        return _operator == operator && _addr == operatorFeeReceiver;
    }
}
