// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../interfaces/IMintableERC20.sol";

/**
 * @title FaucetMinter
 * Simplest contract for faucet minting.
 */
contract FaucetMinter is IMintableERC20 {
    address public immutable token;
    uint256 public immutable limit;

    event Mint(address minter, address to, uint256 amount);

    constructor(address _token, uint256 _limit) {
        token = _token;
        limit = _limit;
    }

    /**
     * @dev Mints the specified amount of tokens.
     * This contract should have minting permissions assigned to it in the token contract.
     * @param _to address of the tokens receiver.
     * @param _amount amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external override {
        require(_amount <= limit, "FaucetMinter: too much");

        IMintableERC20(token).mint(_to, _amount);

        emit Mint(msg.sender, _to, _amount);
    }
}
