// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

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
            IERC4626 yieldVault = IERC4626(params.yield);
            uint256 buffer = params.buffer;
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
            _yieldParams.yield == yieldAddress || investedAssetsAmount == 0,
            "ZkBobCompoundingPool: Invested amount should be 0 in case of changing yield"
        );
        require(
            _yieldParams.yield == address(0) || _yieldParams.interestReceiver != address(0),
            "ZkBobCompoundingPool: interest receiver should not be address(0) for existed yield"
        );

        if (_yieldParams.yield != yieldAddress) {
            if (_yieldParams.yield != address(0)) {
                IERC20(token).approve(_yieldParams.yield, type(uint256).max);
            }
            if (yieldAddress != address(0)) {
                IERC20(token).approve(yieldAddress, 0);
                _claim(0, yieldAddress, yieldParams.interestReceiver);
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
        IERC4626 yieldVault = IERC4626(params.yield);

        uint256 currentDust = params.dust;
        if (currentDust > maxRebalanceAmount) {
            return;
        }
        if (minRebalanceAmount < currentDust) {
            minRebalanceAmount = currentDust;
        }

        if (address(yieldVault) == address(0)) {
            return;
        }

        address operator = params.yieldOperator;
        require(
            operator == address(0) || operator == msg.sender,
            "ZkBobCompoundingPool: Rebalance is an operator-called method"
        );

        uint256 underlyingBalance = IERC20(token).balanceOf(address(this));
        uint256 buffer = params.buffer;

        uint256 balancesDiff = (underlyingBalance >= buffer) ? underlyingBalance - buffer : buffer - underlyingBalance;
        balancesDiff = (balancesDiff >= minRebalanceAmount)
            ? ((balancesDiff <= maxRebalanceAmount) ? balancesDiff : maxRebalanceAmount)
            : 0;
        if (balancesDiff <= params.dust) {
            return;
        }
        uint256 vaultAssets = investedAssetsAmount;
        uint256 maxInvestedAmount = params.maxInvestedAmount;
        if (underlyingBalance > buffer) {
            if (vaultAssets + balancesDiff > maxInvestedAmount) {
                balancesDiff = maxInvestedAmount - vaultAssets;
                if (balancesDiff < minRebalanceAmount) {
                    return;
                }
                investedAssetsAmount = maxInvestedAmount;
            } else {
                investedAssetsAmount += balancesDiff;
            }
            yieldVault.deposit(balancesDiff, address(this));
            emit Rebalance(address(yieldVault), 0, balancesDiff);
        } else {
            if (balancesDiff > vaultAssets) {
                balancesDiff = vaultAssets;
                if (balancesDiff < minRebalanceAmount) {
                    return;
                }
                investedAssetsAmount = 0;
            } else {
                investedAssetsAmount -= balancesDiff;
            }
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

        address yieldAddress = params.yield;

        if (yieldAddress == address(0)) {
            return 0;
        }

        address operator = params.yieldOperator;
        require(
            operator == address(0) || operator == msg.sender, "ZkBobCompoundingPool: Claim is an operator-called method"
        );

        uint256 dust = params.dust;
        minClaimAmount = minClaimAmount > dust ? minClaimAmount : dust;

        return _claim(minClaimAmount, yieldAddress, params.interestReceiver);
    }

    function _claim(
        uint256 minClaimAmount,
        address yieldAddress,
        address interestReceiver
    )
        internal
        returns (uint256)
    {
        IERC4626 yieldVault = IERC4626(yieldAddress);
        uint256 currentInvestedSharesAmount = yieldVault.balanceOf(address(this));

        uint256 toClaimAmount = yieldVault.convertToAssets(currentInvestedSharesAmount) - investedAssetsAmount;

        if (toClaimAmount < minClaimAmount || toClaimAmount == 0) {
            return 0;
        }

        yieldVault.withdraw(toClaimAmount, interestReceiver, address(this));

        emit Claimed(address(yieldVault), toClaimAmount);
        return toClaimAmount;
    }
}
