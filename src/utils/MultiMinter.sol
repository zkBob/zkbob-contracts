// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../interfaces/IMintableERC20.sol";

/**
 * @title MultiMinter
 */
contract MultiMinter {
    address public admin;
    IMintableERC20 public token;
    mapping(address => bool) public minter;

    constructor(address _token) {
        admin = msg.sender;
        token = IMintableERC20(_token);
    }

    function setAdmin(address _admin) external {
        require(msg.sender == admin, "MultiMinter: not an admin");
        admin = _admin;
    }

    function setMinter(address _minter, bool _enabled) external {
        require(msg.sender == admin, "MultiMinter: not an admin");
        minter[_minter] = _enabled;
    }

    function mint(address _to, uint256 _amount) external {
        require(minter[msg.sender], "MultiMinter: not a minter");
        token.mint(_to, _amount);
    }
}
