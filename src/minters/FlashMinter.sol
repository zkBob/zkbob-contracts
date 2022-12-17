// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IMintableERC20.sol";
import "../interfaces/IBurnableERC20.sol";
import "../utils/Ownable.sol";

/**
 * @title FlashMinter
 * BOB flash minter middleware.
 */
contract FlashMinter is IERC3156FlashLender, ReentrancyGuard, Ownable {
    bytes32 private constant _RETURN_VALUE = keccak256("ERC3156FlashBorrower.onFlashLoan");

    address public immutable token;

    uint96 public limit; // max limit for flash mint amount
    address public treasury; // receiver of flash mint fees

    uint64 public fee; // fee percentage * 1 ether
    uint96 public maxFee; // max fee in absolute values

    event FlashMint(address indexed _receiver, uint256 _amount, uint256 _fee);

    constructor(address _token, uint96 _limit, address _treasury, uint64 _fee, uint96 _maxFee) {
        require(_treasury != address(0) || _fee == 0, "FlashMinter: invalid fee config");
        token = _token;
        limit = _limit;
        treasury = _treasury;
        _setFees(_fee, _maxFee);
    }

    function updateConfig(uint96 _limit, address _treasury, uint64 _fee, uint96 _maxFee) external onlyOwner {
        require(_treasury != address(0) || _fee == 0, "FlashMinter: invalid fee config");
        limit = _limit;
        treasury = _treasury;
        _setFees(_fee, _maxFee);
    }

    function _setFees(uint64 _fee, uint96 _maxFee) internal {
        require(_fee <= 0.01 ether, "FlashMinter: fee too large");
        (fee, maxFee) = (_fee, _maxFee);
    }

    /**
     * @dev Returns the maximum amount of tokens available for loan.
     * @param _token The address of the token that is requested.
     * @return The amount of token that can be loaned.
     */
    function maxFlashLoan(address _token) public view virtual override returns (uint256) {
        return token == _token ? limit : 0;
    }

    /**
     * @dev Returns the fee applied when doing flash loans.
     * @param _token The token to be flash loaned.
     * @param _amount The amount of tokens to be loaned.
     * @return The fees applied to the corresponding flash loan.
     */
    function flashFee(address _token, uint256 _amount) public view virtual override returns (uint256) {
        require(token == _token, "FlashMinter: wrong token");
        return _flashFee(_amount);
    }

    /**
     * @dev Returns the fee applied when doing flash loans.
     * @param _amount The amount of tokens to be loaned.
     * @return The fees applied to the corresponding flash loan.
     */
    function _flashFee(uint256 _amount) internal view virtual returns (uint256) {
        (uint64 _fee, uint96 _maxFee) = (fee, maxFee);
        uint256 flashFee = _amount * _fee / 1 ether;
        return flashFee > _maxFee ? _maxFee : flashFee;
    }

    /**
     * @dev Performs a flash loan. New tokens are minted and sent to the
     * `receiver`, who is required to implement the IERC3156FlashBorrower
     * interface. By the end of the flash loan, the receiver is expected to own
     * amount + fee tokens and have them approved back to the token contract itself so
     * they can be burned.
     * @param _receiver The receiver of the flash loan. Should implement the
     * IERC3156FlashBorrower.onFlashLoan interface.
     * @param _token The token to be flash loaned. Only configured token is
     * supported.
     * @param _amount The amount of tokens to be loaned.
     * @param _data An arbitrary data that is passed to the receiver.
     * @return `true` if the flash loan was successful.
     */
    function flashLoan(
        IERC3156FlashBorrower _receiver,
        address _token,
        uint256 _amount,
        bytes calldata _data
    )
        public
        override
        nonReentrant
        returns (bool)
    {
        require(token == _token, "FlashMinter: wrong token");
        require(_amount <= limit, "FlashMinter: amount exceeds maxFlashLoan");
        uint256 fee = _flashFee(_amount);
        IMintableERC20(_token).mint(address(_receiver), _amount);
        require(
            _receiver.onFlashLoan(msg.sender, _token, _amount, fee, _data) == _RETURN_VALUE,
            "FlashMinter: invalid return value"
        );
        IBurnableERC20(_token).burnFrom(address(_receiver), _amount);
        if (fee > 0) {
            IERC20(_token).transferFrom(address(_receiver), treasury, fee);
        }

        emit FlashMint(address(_receiver), _amount, fee);

        return true;
    }
}
