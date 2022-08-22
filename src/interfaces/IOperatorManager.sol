//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IOperatorManager {
    // Check if message sender is operator now
    function is_operator() external view returns(bool);

    // Get an active operator address
    // In case of multiple authorized operator return any address
    // In case of unlimited access to the Pool - return zero address
    function operator() external view returns(address);
}
