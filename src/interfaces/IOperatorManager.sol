// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

interface IOperatorManager {
    function isOperator(address _addr) external view returns (bool);

    function operatorURI() external view returns (string memory);
}
