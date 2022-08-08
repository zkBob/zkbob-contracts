// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/ICToken.sol";
import "../interfaces/IComptroller.sol";
import "../interfaces/ILegacyERC20.sol";
import "../interfaces/IYieldImplementation.sol";

/**
 * @title CompoundYieldImplementation
 * @dev This contract contains token-specific logic for investing ERC20 tokens into Compound protocol.
 */
contract CompoundYieldImplementation is IYieldImplementation {
    using SafeERC20 for IERC20;
    using SafeERC20 for ICToken;

    uint256 internal constant SUCCESS = 0;

    uint256[100] internal __gap__;

    mapping(address => address) internal interestToken;

    /**
     * @dev Tells the address of the COMP token in the Ethereum Mainnet.
     */
    function compToken() public pure virtual returns (IERC20) {
        return IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    }

    /**
     * @dev Tells the address of the Comptroller contract in the Ethereum Mainnet.
     */
    function comptroller() public pure virtual returns (IComptroller) {
        return IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    }

    function initialize(address _token) external {
        address cToken = interestToken[_token];
        if (cToken == address(0)) {
            interestToken[0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48] = 0x39AA39c021dfbaE8faC545936693aC917d5E7563;
            interestToken[0xdAC17F958D2ee523a2206206994597C13D831ec7] = 0xf650C3d88D12dB855b8bf7D11Be6C55A4e07dCC9;
            interestToken[0x6B175474E89094C44Da98b954EedeAC495271d0F] = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;
            cToken = interestToken[_token];
        }
        require(cToken != address(0), "CompoundYieldImplementation: unsupported token");

        // SafeERC20.safeApprove does not work here in case of possible interest reinitialization,
        // since it does not allow positive->positive allowance change. However, it would be safe to make such change here.
        ILegacyERC20(_token).approve(cToken, type(uint256).max);
    }

    /**
     * @dev Tells the current amount of underlying tokens that was invested into the Compound protocol.
     * @param _token address of the underlying token.
     * @return currently invested value.
     */
    function investedAmount(address _token) external override returns (uint256) {
        address cToken = interestToken[_token];

        return ICToken(cToken).balanceOfUnderlying(address(this));
    }

    /**
     * @dev Invests the given amount of tokens to the Compound protocol.
     * Converts _amount of TOKENs into X cTOKENs.
     * @param _token address of the invested token contract.
     * @param _amount amount of tokens to invest.
     */
    function invest(address _token, uint256 _amount) external override {
        require(ICToken(interestToken[_token]).mint(_amount) == SUCCESS);
    }

    /**
     * @dev Withdraws at least _amount of tokens from the Compound protocol.
     * Converts X cTOKENs into _amount of TOKENs.
     * @param _token address of the invested token contract.
     * @param _amount minimal amount of tokens to withdraw.
     */
    function withdraw(address _token, uint256 _amount) external override {
        address cToken = interestToken[_token];

        uint256 balance = IERC20(_token).balanceOf(address(this));

        require(ICToken(cToken).redeemUnderlying(_amount) == SUCCESS);

        uint256 redeemed = IERC20(_token).balanceOf(address(this)) - balance;

        require(redeemed >= _amount);
    }

    /**
     * @dev Claims Comp token received by supplying underlying tokens and transfers it to the associated COMP receiver.
     */
    function farmExtra(address _token, address _to, bytes calldata _data) external returns (bytes memory) {
        address[] memory markets = abi.decode(_data, (address[]));
        address[] memory holders = new address[](1);
        holders[0] = address(this);
        comptroller().claimComp(holders, markets, false, true);
        uint256 balance = compToken().balanceOf(address(this));
        compToken().transfer(_to, balance);
        return abi.encode(balance);
    }

    /**
     * @dev Last-resort function for returning assets to the Omnibridge contract in case of some failures in the logic.
     * Disables this contract and transfers locked tokens back to the mediator.
     * Only owner is allowed to call this method.
     * @param _token address of the invested token contract that should be disabled.
     */
    function exit(address _token) external {
        address cToken = interestToken[_token];

        uint256 cTokenBalance = ICToken(cToken).balanceOf(address(this));

        if (cTokenBalance > 0) {
            require(ICToken(cToken).redeem(cTokenBalance) == SUCCESS);
        }

        IERC20(_token).safeApprove(cToken, 0);
    }
}
