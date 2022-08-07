// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../interfaces/IOperatorManager.sol";
import "../../utils/Ownable.sol";

contract MutableOperatorManager is IOperatorManager, Ownable {
    address public operator;
    string public operatorURI;

    constructor(address _operator, string memory _operatorURI) Ownable() {
        _setOperator(_operator, _operatorURI);
    }

    function setOperator(address _operator, string memory _endpoint) external onlyOwner {
        _setOperator(_operator, _endpoint);
    }

    function _setOperator(address _operator, string memory _operatorURI) internal {
        if (_operator == address(0)) {
            require(bytes(_operatorURI).length == 0, "OperatorManager: non-empty uri");
        } else {
            require(bytes(_operatorURI).length > 0, "OperatorManager: empty uri");
        }
        operator = _operator;
        operatorURI = _operatorURI;
    }

    function isOperator(address _addr) external view override returns (bool) {
        return operator == _addr || operator == address(0);
    }
}
