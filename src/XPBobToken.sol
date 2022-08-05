// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./token/ERC677.sol";
import "./token/ERC2612.sol";
import "./token/MintableERC20.sol";
import "./utils/Claimable.sol";

/**
 * @title XPBobToken
 */
contract XPBobToken is ERC20, ERC677, ERC2612, MintableERC20, Claimable {
    /**
     * @dev Creates a proxy implementation for XPBobToken.
     * @param _self address of the proxy contract, linked to the deployed implementation,
     * required for correct EIP712 domain derivation.
     */
    constructor(address _self) ERC20("", "") ERC2612(_self) {}

    /**
     * @dev Returns the name of the token.
     */
    function name() public view override returns (string memory) {
        return "XP BOB Token";
    }

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() public view override returns (string memory) {
        return "xpBOB";
    }

    /**
     * @dev Burns tokens from the caller.
     * @param _value amount of tokens to burn. Should be less than or equal to caller balance.
     */
    function burn(uint256 _value) external {
        _burn(_msgSender(), _value);
    }
}
