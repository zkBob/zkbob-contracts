// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../utils/Ownable.sol";
import "../interfaces/IMintableERC20.sol";
import "./BaseERC20.sol";
import "../interfaces/IMintableERC20.sol";
import "../interfaces/IBurnableERC20.sol";

/**
 * @title ERC20MintBurn
 */
abstract contract ERC20MintBurn is IMintableERC20, IBurnableERC20, Ownable, BaseERC20 {
    address public minter;

    /**
     * @dev Updates the address of the minter account.
     * Callable only by the contract owner.
     * @param _minter address of the new minter EOA or contract.
     */
    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
    }

    /**
     * @dev Mints the specified amount of tokens.
     * Callable only by the current minter address.
     * @param _to address of the tokens receiver.
     * @param _amount amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external {
        require(msg.sender == minter, "ERC20MintBurn: not a minter");

        _mint(_to, _amount);
    }

    /**
     * @dev Burns tokens from the caller.
     * Callable only by the current minter address.
     * @param _value amount of tokens to burn. Should be less than or equal to caller balance.
     */
    function burn(uint256 _value) external virtual {
        require(msg.sender == minter, "ERC20MintBurn: not a minter");

        _burn(msg.sender, _value);
    }
}
