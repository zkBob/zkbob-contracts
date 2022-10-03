// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

contract Sacrifice {
    constructor(address _receiver) payable {
        selfdestruct(payable(_receiver));
    }
}
