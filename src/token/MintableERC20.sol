// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../utils/Ownable.sol";
import "../interfaces/IMintableERC20.sol";

/**
 * @title MintableERC20
 */
abstract contract MintableERC20 is IMintableERC20, Ownable, ERC20 {
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
        require(msg.sender == minter, "MintableERC20: not a minter");

        _mint(_to, _amount);
    }
}
