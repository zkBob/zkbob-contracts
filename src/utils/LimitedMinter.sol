// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../utils/Ownable.sol";
import "../interfaces/IMintableERC20.sol";
import "../interfaces/IBurnableERC20.sol";
import "../interfaces/IERC677Receiver.sol";

/**
 * @title LimitedMinter
 * BOB minting/burning middleware with simple usage quotas.
 */
contract LimitedMinter is IMintableERC20, IBurnableERC20, IERC677Receiver, Ownable {
    address public immutable token;

    uint128 public mintQuota; // remaining minting quota
    uint128 public burnQuota; // remaining burning quota

    mapping(address => bool) public isMinter;

    constructor(address _token, uint128 _mintQuota, uint128 _burnQuota) {
        token = _token;
        mintQuota = _mintQuota;
        burnQuota = _burnQuota;
    }

    /**
     * @dev Updates mint/burn permissions for the given address.
     * Callable only by the contract owner.
     * @param _account managed minter account address.
     * @param _enabled true, if enabling minting/burning, false otherwise.
     */
    function setMinter(address _account, bool _enabled) external onlyOwner {
        isMinter[_account] = _enabled;
    }

    /**
     * @dev Mints the specified amount of tokens.
     * This contract should have minting permissions assigned to it in the token contract.
     * Callable only by one of the minter addresses.
     * @param _to address of the tokens receiver.
     * @param _amount amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external override {
        require(isMinter[msg.sender], "LimitedMinter: not a minter");
        unchecked {
            require(mintQuota >= uint128(_amount), "LimitedMinter: exceeds minting quota");
            (mintQuota, burnQuota) = (mintQuota - uint128(_amount), burnQuota + uint128(_amount));
        }
        IMintableERC20(token).mint(_to, _amount);
    }

    /**
     * @dev Burns tokens sent to the address.
     * Callable only by one of the minter addresses.
     * Caller should send specified amount of tokens to this contract, prior to calling burn.
     * @param _amount amount of tokens to burn.
     */
    function burn(uint256 _amount) external override {
        require(isMinter[msg.sender], "LimitedMinter: not a burner");
        _burn(_amount);
    }

    /**
     * @dev ERC677 callback for burning tokens atomically.
     * @param _from tokens sender, should correspond to one of the minting addresses.
     * @param _amount amount of sent/burnt tokens.
     * @param _data extra data, not used.
     */
    function onTokenTransfer(address _from, uint256 _amount, bytes calldata _data) external override returns (bool) {
        require(msg.sender == address(token), "LimitedMinter: not a token");
        require(isMinter[_from], "LimitedMinter: not a burner");
        _burn(_amount);
        return true;
    }

    /**
     * @dev Adjusts mint/burn quotas for the given address.
     * Callable only by the contract owner.
     * @param _dMint delta for minting quota.
     * @param _dBurn delta for burning quota.
     */
    function adjustQuotas(int256 _dMint, int256 _dBurn) external onlyOwner {
        (uint256 newMintQuota, uint256 newBurnQuota) = (uint256(mintQuota), uint256(burnQuota));
        if (_dMint > 0) {
            newMintQuota += uint256(_dMint);
        } else if (uint256(-_dMint) < newMintQuota) {
            newMintQuota -= uint256(-_dMint);
        } else {
            newMintQuota = 0;
        }
        if (_dBurn > 0) {
            newBurnQuota += uint256(_dBurn);
        } else if (uint256(-_dBurn) < newBurnQuota) {
            newBurnQuota -= uint256(-_dBurn);
        } else {
            newBurnQuota = 0;
        }
        (mintQuota, burnQuota) = (uint128(newMintQuota), uint128(newBurnQuota));
    }

    /**
     * @dev Internal function for delegating burn call to the token contract and adjusting quotas.
     * @param _amount amount of tokens to burn.
     */
    function _burn(uint256 _amount) internal {
        unchecked {
            require(burnQuota >= uint128(_amount), "LimitedMinter: exceeds burning quota");
            (mintQuota, burnQuota) = (mintQuota + uint128(_amount), burnQuota - uint128(_amount));
        }
        IBurnableERC20(token).burn(_amount);
    }
}
