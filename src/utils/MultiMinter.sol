// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IMintableERC20.sol";

/**
 * @title MultiMinter
 */
contract MultiMinter is Ownable {
    IMintableERC20 public token;
    mapping(address => bool) public minter;

    event UpdatedMinter(address indexed minter, bool enabled);

    /**
     * @dev Creates a simple token minter multiplexer.
     * @param _token address of the token contract to mint.
     */
    constructor(address _token) Ownable() {
        token = IMintableERC20(_token);
    }

    /**
     * @dev Updates minter account permissions.
     * Callable only by the contract owner.
     * @param _minter address of the minter EOA or contract.
     * @param _enabled true if minting should be enabled, false otherwise.
     */
    function setMinter(address _minter, bool _enabled) external onlyOwner {
        minter[_minter] = _enabled;
        emit UpdatedMinter(_minter, _enabled);
    }

    /**
     * @dev Mints the specified amount of tokens.
     * Callable only by one of the allowed minter accounts.
     * Token minter should be configured to the address of this contract.
     * @param _to address of the tokens receiver.
     * @param _amount amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external {
        require(minter[msg.sender], "MultiMinter: not a minter");
        token.mint(_to, _amount);
    }
}
