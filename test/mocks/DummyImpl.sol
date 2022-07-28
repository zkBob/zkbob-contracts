// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

contract DummyImpl {
    uint256 public value;
    uint256 public immutable const;

    constructor(uint256 _const) {
        const = _const;
    }

    function increment() external {
        value++;
    }
}
