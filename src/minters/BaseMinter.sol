// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../utils/Ownable.sol";
import "../interfaces/IMintableERC20.sol";
import "../interfaces/IBurnableERC20.sol";
import "../interfaces/IERC677Receiver.sol";

/**
 * @title BaseMinter
 * Base contract for BOB minting/burning middleware
 */
abstract contract BaseMinter is IMintableERC20, IBurnableERC20, IERC677Receiver, Ownable {
    address public immutable token;

    mapping(address => bool) public isMinter;

    event UpdateMinter(address indexed minter, bool enabled);
    event Mint(address minter, address to, uint256 amount);
    event Burn(address burner, address from, uint256 amount);

    constructor(address _token) {
        token = _token;
    }

    /**
     * @dev Updates mint/burn permissions for the given address.
     * Callable only by the contract owner.
     * @param _account managed minter account address.
     * @param _enabled true, if enabling minting/burning, false otherwise.
     */
    function setMinter(address _account, bool _enabled) external onlyOwner {
        isMinter[_account] = _enabled;

        emit UpdateMinter(_account, _enabled);
    }

    /**
     * @dev Mints the specified amount of tokens.
     * This contract should have minting permissions assigned to it in the token contract.
     * Callable only by one of the minter addresses.
     * @param _to address of the tokens receiver.
     * @param _amount amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external override {
        require(isMinter[msg.sender], "BaseMinter: not a minter");

        _beforeMint(_amount);
        IMintableERC20(token).mint(_to, _amount);

        emit Mint(msg.sender, _to, _amount);
    }

    /**
     * @dev Burns tokens sent to the address.
     * Callable only by one of the minter addresses.
     * Caller should send specified amount of tokens to this contract, prior to calling burn.
     * @param _amount amount of tokens to burn.
     */
    function burn(uint256 _amount) external override {
        require(isMinter[msg.sender], "BaseMinter: not a burner");

        _beforeBurn(_amount);
        IBurnableERC20(token).burn(_amount);

        emit Burn(msg.sender, msg.sender, _amount);
    }

    /**
     * @dev Burns pre-approved tokens from the other address.
     * Callable only by one of the burner addresses.
     * Minters should handle with extra care cases when first argument is not msg.sender.
     * @param _from account to burn tokens from.
     * @param _amount amount of tokens to burn. Should be less than or equal to account balance.
     */
    function burnFrom(address _from, uint256 _amount) external override {
        require(isMinter[msg.sender], "BaseMinter: not a burner");

        _beforeBurn(_amount);
        IBurnableERC20(token).burnFrom(_from, _amount);

        emit Burn(msg.sender, _from, _amount);
    }

    /**
     * @dev ERC677 callback for burning tokens atomically.
     * @param _from tokens sender, should correspond to one of the minting addresses.
     * @param _amount amount of sent/burnt tokens.
     * @param _data extra data, not used.
     */
    function onTokenTransfer(address _from, uint256 _amount, bytes calldata _data) external override returns (bool) {
        require(msg.sender == address(token), "BaseMinter: not a token");
        require(isMinter[_from], "BaseMinter: not a burner");

        _beforeBurn(_amount);
        IBurnableERC20(token).burn(_amount);

        emit Burn(_from, _from, _amount);

        return true;
    }

    function _beforeMint(uint256 _amount) internal virtual;

    function _beforeBurn(uint256 _amount) internal virtual;
}
