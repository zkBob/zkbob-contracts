// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "./ZkBobPool.sol";

/**
 * @title ZkBobCompoundingMixin
 */
abstract contract ZkBobCompoundingMixin is ZkBobPool {
    using SafeERC20 for IERC20;

    uint256 public investedAssetsAmount;

    struct YieldParams {
        // ERC4626 vault address (or address(0) if not set)
        address yield;
        // maximum amount of underlying tokens that can be invested into vault
        uint256 maxInvestedAmount;
        // expected amount of underlying tokens to be left at the pool after successful rebalance
        uint96 buffer;
        // slippage/rounding protection buffer, small part of accumulated interest that is non-claimable
        uint96 dust;
        // address to receive accumulated interest during the rebalance
        address interestReceiver;
        // operator address (or address(0) if permissionless)
        address yieldOperator;
    }

    YieldParams public yieldParams;

    event UpdateYieldParams(YieldParams yieldParams);
    event Claimed(address indexed yield, uint256 amount);
    event Rebalance(address indexed yield, uint256 withdrawn, uint256 deposited);

    // @inheritdoc ZkBobPool
    function _withdrawToken(address _user, uint256 _tokenAmount) internal override {
        uint256 underlyingBalance = IERC20(token).balanceOf(address(this));
        if (underlyingBalance < _tokenAmount) {
            YieldParams storage params = yieldParams;
            (IERC4626 yieldVault, uint256 buffer) = (IERC4626(params.yield), params.buffer);
            uint256 remainder = _tokenAmount - underlyingBalance;
            uint256 vaultAmount = investedAssetsAmount;
            if (vaultAmount >= remainder + buffer) {
                investedAssetsAmount = vaultAmount - remainder - buffer;
                yieldVault.withdraw(remainder + buffer, address(this), address(this));
                emit Rebalance(address(yieldVault), remainder + buffer, 0);
            } else {
                investedAssetsAmount = 0;
                yieldVault.withdraw(vaultAmount, address(this), address(this));
                emit Rebalance(address(yieldVault), vaultAmount, 0);
            }
        }
        IERC20(token).safeTransfer(_user, _tokenAmount);
    }

    /**
     * @dev Updates yield parameters.
     * Callable only by the contract owner / proxy admin.
     * @param _yieldParams new yield parameters.
     */
    function updateYieldParams(YieldParams memory _yieldParams) external onlyOwner {
        address yieldAddress = yieldParams.yield;
        require(
            _yieldParams.yield == yieldAddress || investedAssetsAmount == 0, "ZkBobCompounding: another yield is active"
        );
        require(
            _yieldParams.yield == address(0) || _yieldParams.interestReceiver != address(0),
            "ZkBobCompounding: zero interest receiver"
        );

        if (_yieldParams.yield != yieldAddress) {
            if (_yieldParams.yield != address(0)) {
                IERC20(token).approve(_yieldParams.yield, type(uint256).max);
            }
            if (yieldAddress != address(0)) {
                IERC20(token).approve(yieldAddress, 0);
                _claim(0, yieldAddress, yieldParams.interestReceiver, 0);
            }
        }

        yieldParams = _yieldParams;

        emit UpdateYieldParams(_yieldParams);
    }

    /**
     * @dev Rebalances yield bearing tokens.
     * @param minRebalanceAmount minimum amount of token to move between underlying balance and yield.
     * @param maxRebalanceAmount maximum amount of token to move between underlying balance and yield.
     */
    function rebalance(uint256 minRebalanceAmount, uint256 maxRebalanceAmount) external {
        if (maxRebalanceAmount < minRebalanceAmount) {
            (minRebalanceAmount, maxRebalanceAmount) = (maxRebalanceAmount, minRebalanceAmount);
        }

        YieldParams storage params = yieldParams;
        (IERC4626 yieldVault, uint256 currentDust, address operator, uint256 buffer, uint256 maxInvestedAmount) =
            (IERC4626(params.yield), params.dust, params.yieldOperator, params.buffer, params.maxInvestedAmount);

        if (currentDust > maxRebalanceAmount) {
            return;
        }
        if (minRebalanceAmount < currentDust) {
            minRebalanceAmount = currentDust;
        }

        if (address(yieldVault) == address(0)) {
            return;
        }

        require(operator == address(0) || operator == msg.sender, "ZkBobCompounding: not authorized");

        uint256 underlyingBalance = IERC20(token).balanceOf(address(this));
        uint256 vaultAssets = investedAssetsAmount;

        if (
            underlyingBalance >= buffer + minRebalanceAmount
                && investedAssetsAmount + minRebalanceAmount <= maxInvestedAmount
        ) {
            uint256 balancesDiff = underlyingBalance - buffer;
            if (vaultAssets + balancesDiff > maxInvestedAmount) {
                balancesDiff = maxInvestedAmount - vaultAssets;
            }
            if (balancesDiff > maxRebalanceAmount) {
                balancesDiff = maxRebalanceAmount;
            }
            investedAssetsAmount += balancesDiff;
            yieldVault.deposit(balancesDiff, address(this));
            emit Rebalance(address(yieldVault), 0, balancesDiff);
        } else if (underlyingBalance + minRebalanceAmount <= buffer && vaultAssets >= minRebalanceAmount) {
            uint256 balancesDiff = buffer - underlyingBalance;
            if (balancesDiff > vaultAssets) {
                balancesDiff = vaultAssets;
            }
            if (balancesDiff > maxRebalanceAmount) {
                balancesDiff = maxRebalanceAmount;
            }
            investedAssetsAmount -= balancesDiff;
            yieldVault.withdraw(balancesDiff, address(this), address(this));
            emit Rebalance(address(yieldVault), balancesDiff, 0);
        }
    }

    /**
     * @dev Collects accumulated fees and generated yield for the specific collateral.
     * Callable only by the contract owner / proxy admin / yield admin.
     * @param minClaimAmount minimum amount of token to claim.
     * @return Claimed amount.
     */
    function claim(uint256 minClaimAmount) external returns (uint256) {
        YieldParams storage params = yieldParams;

        (address yieldAddress, address operator, uint256 dust, address interestReceiver) =
            (params.yield, params.yieldOperator, params.dust, params.interestReceiver);

        if (yieldAddress == address(0)) {
            return 0;
        }
        require(operator == address(0) || operator == msg.sender, "ZkBobCompounding: not authorized");

        minClaimAmount = minClaimAmount > dust ? minClaimAmount : dust;

        return _claim(minClaimAmount, yieldAddress, interestReceiver, dust);
    }

    /**
     * @dev Withdraws everything from the yield.
     * @param targetAmount amount of token to withdraw.
     * Callable only by the contract owner / proxy admin / yield admin.
     */
    function emergencyWithdraw(uint256 targetAmount) external onlyOwner {
        YieldParams storage params = yieldParams;

        (address yieldAddress, address interestReceiver) = (params.yield, params.interestReceiver);

        if (yieldAddress == address(0)) {
            return;
        }

        IERC4626 yieldVault = IERC4626(yieldAddress);

        yieldVault.withdraw(targetAmount, address(this), address(this));
        uint256 currentInvestedAssetsAmount = investedAssetsAmount;

        if (targetAmount > currentInvestedAssetsAmount) {
            IERC20(token).transfer(interestReceiver, targetAmount - currentInvestedAssetsAmount);
            emit Claimed(yieldAddress, targetAmount - currentInvestedAssetsAmount);
            targetAmount = currentInvestedAssetsAmount;
        }

        investedAssetsAmount = currentInvestedAssetsAmount - targetAmount;

        params.maxInvestedAmount = 0;
        emit Rebalance(yieldAddress, targetAmount, 0);
    }

    function _claim(
        uint256 minClaimAmount,
        address yieldAddress,
        address interestReceiver,
        uint256 dust
    )
        internal
        returns (uint256)
    {
        IERC4626 yieldVault = IERC4626(yieldAddress);
        uint256 currentInvestedSharesAmount = yieldVault.balanceOf(address(this));
        uint256 lockedAmount = investedAssetsAmount + dust;
        uint256 allAssets = yieldVault.convertToAssets(currentInvestedSharesAmount);

        if (allAssets < lockedAmount) {
            return 0;
        }

        uint256 toClaimAmount = allAssets - lockedAmount;

        if (toClaimAmount < minClaimAmount || toClaimAmount == 0) {
            return 0;
        }

        yieldVault.withdraw(toClaimAmount, interestReceiver, address(this));

        emit Claimed(address(yieldVault), toClaimAmount);
        return toClaimAmount;
    }
}
