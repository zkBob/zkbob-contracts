// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./proxy/EIP1967Admin.sol";
import "./token/ERC677.sol";
import "./token/ERC2612.sol";
import "./token/MintableERC20.sol";
import "./token/Recovery.sol";
import "./utils/Blocklist.sol";
import "./utils/Claimable.sol";

/**
 * @title BobToken
 */
contract BobToken is EIP1967Admin, ERC20, ERC677, ERC2612, MintableERC20, Recovery, Blocklist, Claimable {
    /**
     * @dev Creates a proxy implementation for BobToken.
     * @param _self address of the proxy contract, linked to the deployed implementation,
     * required for correct EIP712 domain derivation.
     */
    constructor(address _self) ERC20("", "") ERC2612(_self) {}

    /**
     * @dev Returns the name of the token.
     */
    function name() public view override returns (string memory) {
        return "BOB";
    }

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() public view override returns (string memory) {
        return "BOB";
    }

    /**
     * @dev Makes ERC20 transfer, if none of participants is blocklisted.
     * ERC677 transferAndCall also depends on this function, thus uses the same blocklist restrictions.
     * Note that blocked user is still able to issue approvals/permits,
     * but no one will be able to use pre-existing/newly created approvals from blocked user.
     * @param _to tokens receiver.
     * @param _amount amount of transferred tokens.
     */
    function transfer(address _to, uint256 _amount) public override returns (bool) {
        require(!blocked[_msgSender()], "BOB: sender blocked");
        require(!blocked[_to], "BOB: receiver blocked");
        return super.transfer(_to, _amount);
    }

    /**
     * @dev Makes ERC20 transferFrom, if none of participants is blocklisted.
     * @param _from tokens sender.
     * @param _to tokens receiver.
     * @param _amount amount of transferred tokens.
     */
    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        require(!blocked[_msgSender()], "BOB: spender blocked");
        require(!blocked[_from], "BOB: sender blocked");
        require(!blocked[_to], "BOB: receiver blocked");
        return super.transferFrom(_from, _to, _amount);
    }

    /**
     * @dev Tells if caller is the contract owner.
     * Gives ownership rights to the proxy admin as well.
     * @return true, if caller is the contract owner or proxy admin.
     */
    function _isOwner() internal view override returns (bool) {
        return super._isOwner() || _admin() == _msgSender();
    }
}
