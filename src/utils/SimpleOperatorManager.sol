//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IOperatorManager.sol";

contract SimpleOperatorManager is IOperatorManager {
    address immutable public op;

    constructor(address _operator) {
        op = _operator;
    }

    function is_operator() external view override returns(bool) {
        return (op == address(0) || op == tx.origin);
    }

    function operator() external view override returns(address) {
        return op;
    }
}