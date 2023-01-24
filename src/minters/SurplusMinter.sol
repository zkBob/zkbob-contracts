// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../utils/Ownable.sol";
import "../interfaces/IMintableERC20.sol";

/**
 * @title SurplusMinter
 * Managing realized and unrealized BOB surplus from debt-minting use-cases.
 */
contract SurplusMinter is Ownable {
    address public immutable token;

    mapping(address => bool) public isMinter;

    uint256 public surplus; // unrealized surplus

    event WithdrawSurplus(address indexed to, uint256 realized, uint256 unrealized);
    event AddSurplus(address indexed from, uint256 surplus);

    constructor(address _token) {
        token = _token;
    }

    /**
     * @dev Updates surplus mint permissions for the given address.
     * Callable only by the contract owner.
     * @param _account managed minter account address.
     * @param _enabled true, if enabling surplus minting, false otherwise.
     */
    function setMinter(address _account, bool _enabled) external onlyOwner {
        isMinter[_account] = _enabled;
    }

    /**
     * @dev Mints potential unrealized surplus.
     * Callable only by the pre-approved surplus minter.
     * Once surplus is realized, it should be transferred to this contract via regular transfer.
     * @param _surplus unrealized surplus to add.
     */
    function add(uint256 _surplus) external {
        require(isMinter[msg.sender], "SurplusMinter: not a minter");

        surplus += _surplus;

        emit AddSurplus(msg.sender, _surplus);
    }

    /**
     * @dev Burns potential unrealized surplus.
     * Callable only by the contract owner.
     * Intended to be used for cancelling mistakenly accounted surplus.
     * @param _surplus unrealized surplus to cancel.
     */
    function burn(uint256 _surplus) external onlyOwner {
        require(_surplus <= surplus, "SurplusMinter: exceeds surplus");
        unchecked {
            surplus -= _surplus;
        }
        emit WithdrawSurplus(address(0), 0, _surplus);
    }

    /**
     * @dev Withdraws surplus.
     * Callable only by the contract owner.
     * Withdrawing realized surplus is prioritised, unrealized surplus is minted only
     * if realized surplus is not enough to cover the requested amount.
     * @param _surplus surplus amount to withdraw/mint.
     */
    function withdraw(address _to, uint256 _surplus) external onlyOwner {
        require(_surplus <= surplus, "SurplusMinter: exceeds surplus");
        unchecked {
            surplus -= _surplus;
        }

        uint256 realized = IERC20(token).balanceOf(address(this));

        if (_surplus > realized) {
            IERC20(token).transfer(_to, realized);
            IMintableERC20(token).mint(_to, _surplus - realized);

            emit WithdrawSurplus(_to, realized, _surplus - realized);
        } else {
            IERC20(token).transfer(_to, _surplus);

            emit WithdrawSurplus(_to, _surplus, 0);
        }
    }
}
