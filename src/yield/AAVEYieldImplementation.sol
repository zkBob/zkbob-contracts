// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IAToken.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/ILegacyERC20.sol";
import "../interfaces/IYieldImplementation.sol";

/**
 * @title AAVEYieldImplementation
 * @dev This contract contains token-specific logic for investing ERC20 tokens into AAVE protocol.
 */
contract AAVEYieldImplementation is IYieldImplementation {
    using SafeERC20 for IERC20;
    using SafeERC20 for IAToken;

    uint256[200] internal __gap__;

    mapping(address => address) internal interestToken;

    ILendingPool public immutable lendingPool;

    constructor(address _lendingPoolAddress) {
        lendingPool = ILendingPool(_lendingPoolAddress);
    }

    function initialize(address _token) external {
        address aToken = lendingPool.getReserveData(_token)[7];
        require(IAToken(aToken).UNDERLYING_ASSET_ADDRESS() == _token);
        interestToken[_token] = aToken;

        // SafeERC20.safeApprove does not work here in case of possible interest reinitialization,
        // since it does not allow positive->positive allowance change. However, it would be safe to make such change here.
        ILegacyERC20(_token).approve(address(lendingPool), type(uint256).max);
    }

    /**
     * @dev Tells the current amount of underlying tokens that was invested into the AAVE protocol.
     * @param _token address of the underlying token.
     * @return currently invested value.
     */
    function investedAmount(address _token) external view override returns (uint256) {
        return IAToken(interestToken[_token]).balanceOf(address(this));
    }

    /**
     * @dev Invests the given amount of tokens to the AAVE protocol.
     * Converts _amount of TOKENs into aTOKENs.
     * @param _token address of the invested token contract.
     * @param _amount amount of tokens to invest.
     */
    function invest(address _token, uint256 _amount) external override {
        lendingPool.deposit(_token, _amount, address(this), 0);
    }

    /**
     * @dev Withdraws at least _amount of tokens from the AAVE protocol.
     * Converts aTOKENs into _amount of TOKENs.
     * @param _token address of the invested token contract.
     * @param _amount minimal amount of tokens to withdraw.
     */
    function withdraw(address _token, uint256 _amount) external override {
        uint256 balance = IERC20(_token).balanceOf(address(this));

        lendingPool.withdraw(_token, _amount, address(this));

        uint256 redeemed = IERC20(_token).balanceOf(address(this)) - balance;

        require(redeemed >= _amount);
    }

    function farmExtra(address _token, address _to, bytes calldata _data) external returns (bytes memory) {
        revert("not supported");
    }

    /**
     * @dev Last-resort function for returning assets to the Omnibridge contract in case of some failures in the logic.
     * Disables this contract and transfers locked tokens back to the mediator.
     * Only owner is allowed to call this method.
     * @param _token address of the invested token contract that should be disabled.
     */
    function exit(address _token) external {
        address aToken = interestToken[_token];

        uint256 aTokenBalance = IAToken(aToken).balanceOf(address(this));

        if (aTokenBalance > 0) {
            // redeem all aTokens
            // it is safe to specify uint256(-1) as max amount of redeemed tokens
            // since the withdraw method of the pool contract will return the entire balance
            lendingPool.withdraw(_token, type(uint256).max, address(this));
        }

        IERC20(_token).safeApprove(address(lendingPool), 0);
    }
}
