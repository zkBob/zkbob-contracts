// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../utils/Ownable.sol";
import "../interfaces/IMintableERC20.sol";
import "../interfaces/IERC677Receiver.sol";

/**
 * @title SurplusMinter
 * Managing realized and unrealized BOB surplus from debt-minting use-cases.
 */
contract SurplusMinter is IERC677Receiver, Ownable {
    address public immutable token;

    mapping(address => bool) public isMinter;

    uint256 public surplus; // unrealized surplus

    event WithdrawSurplus(address indexed to, uint256 realized, uint256 unrealized);
    event AddSurplus(address indexed from, uint256 unrealized);

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
     * @dev Records potential unrealized surplus.
     * Callable only by the pre-approved surplus minter.
     * Once unrealized surplus is realized, it should be transferred to this contract via transferAndCall.
     * @param _surplus unrealized surplus to add.
     */
    function add(uint256 _surplus) external {
        require(isMinter[msg.sender], "SurplusMinter: not a minter");

        surplus += _surplus;

        emit AddSurplus(msg.sender, _surplus);
    }

    /**
     * @dev ERC677 callback. Converts previously recorded unrealized surplus into the realized one.
     * Callable by anyone.
     * @param _from tokens sender.
     * @param _amount amount of tokens corresponding to realized interest.
     * @param _data optional extra data, encoded uint256 amount of unrealized surplus to convert. Defaults to _amount.
     */
    function onTokenTransfer(address _from, uint256 _amount, bytes calldata _data) external override returns (bool) {
        require(msg.sender == token, "SurplusMinter: invalid caller");

        uint256 unrealized = _amount;
        if (_data.length == 32) {
            unrealized = abi.decode(_data, (uint256));
            require(unrealized <= _amount, "SurplusMinter: invalid value");
        }

        if (surplus > unrealized) {
            unchecked {
                surplus -= unrealized;
            }
        } else {
            unrealized = surplus;
            surplus = 0;
        }
        emit WithdrawSurplus(address(this), 0, unrealized);

        return true;
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
        uint256 realized = IERC20(token).balanceOf(address(this));

        if (_surplus > realized) {
            uint256 unrealized = _surplus - realized;
            require(unrealized <= surplus, "SurplusMinter: exceeds surplus");
            unchecked {
                surplus -= unrealized;
            }

            IERC20(token).transfer(_to, realized);
            IMintableERC20(token).mint(_to, unrealized);

            emit WithdrawSurplus(_to, realized, unrealized);
        } else {
            IERC20(token).transfer(_to, _surplus);

            emit WithdrawSurplus(_to, _surplus, 0);
        }
    }
}
