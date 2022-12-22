// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../BobToken.sol";

/**
 * @title PolygonBobToken
 */
contract PolygonBobToken is BobToken {
    event Withdrawn(address indexed account, uint256 value);

    constructor(address _self) BobToken(_self) {}

    function deposit(address _user, bytes calldata _depositData) external {
        mint(_user, abi.decode(_depositData, (uint256)));
    }

    function withdraw(uint256 _amount) external {
        _burn(msg.sender, _amount);

        emit Withdrawn(msg.sender, _amount);
    }
}
