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
        // expected amount of underlying tokens to be left at the pool after successful rebalance
        uint96 buffer;
        // operator address (or address(0) if permissionless)
        address yieldOperator;
        // slippage/rounding protection buffer, small part of accumulated interest that is non-claimable
        uint96 dust;
        // address to receive accumulated interest during the rebalance
        address interestReceiver;
        // maximum amount of underlying tokens that can be invested into vault
        uint256 maxInvestedAmount;
    }

    YieldParams public yieldParams;

    event UpdateYieldParams(YieldParams yieldParams);
    event Claimed(address indexed yield, uint256 amount);
    event Rebalance(address indexed yield, uint256 withdrawn, uint256 deposited);

    // @inheritdoc ZkBobPool
    function _withdrawToken(address _user, uint256 _tokenAmount) internal override {
        uint256 underlyingBalance = IERC20(token).balanceOf(address(this));
        if (underlyingBalance < _tokenAmount) {
            (address yieldAddress, uint256 buffer) = (yieldParams.yield, yieldParams.buffer);
            uint256 remainder = _tokenAmount - underlyingBalance;
            uint256 investedAssets = investedAssetsAmount;
            uint256 withdrawAmount = investedAssets > remainder + buffer ? remainder + buffer : investedAssets;
            investedAssetsAmount = investedAssets - withdrawAmount;
            IERC4626(yieldAddress).withdraw(withdrawAmount, address(this), address(this));
            emit Rebalance(yieldAddress, withdrawAmount, 0);
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
                _claim(yieldAddress, yieldParams.interestReceiver, 0);
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
        (address yieldAddress, address operator, uint256 buffer, uint256 maxInvestedAmount) =
            (yieldParams.yield, yieldParams.yieldOperator, yieldParams.buffer, yieldParams.maxInvestedAmount);

        require(yieldAddress != address(0), "ZkBobCompounding: yield not enabled");
        require(operator == address(0) || operator == msg.sender || _isOwner(), "ZkBobCompounding: not authorized");

        uint256 underlyingBalance = IERC20(token).balanceOf(address(this));
        uint256 investedAssets = investedAssetsAmount;

        if (underlyingBalance < buffer || investedAssets > maxInvestedAmount) {
            uint256 withdrawAmount;
            if (underlyingBalance < buffer) {
                withdrawAmount = buffer - underlyingBalance;
                if (withdrawAmount > investedAssets) {
                    withdrawAmount = investedAssets;
                }
            } else {
                withdrawAmount = investedAssets - maxInvestedAmount;
            }
            if (withdrawAmount > maxRebalanceAmount) {
                withdrawAmount = maxRebalanceAmount;
            }
            require(
                withdrawAmount > 0 && withdrawAmount >= minRebalanceAmount, "ZkBobCompounding: insufficient rebalance"
            );
            investedAssetsAmount = investedAssets - withdrawAmount;
            IERC4626(yieldAddress).withdraw(withdrawAmount, address(this), address(this));
            emit Rebalance(yieldAddress, withdrawAmount, 0);
        } else {
            uint256 depositAmount = underlyingBalance - buffer;
            if (investedAssets + depositAmount > maxInvestedAmount) {
                depositAmount = maxInvestedAmount - investedAssets;
            }
            if (depositAmount > maxRebalanceAmount) {
                depositAmount = maxRebalanceAmount;
            }
            require(
                depositAmount > 0 && depositAmount >= minRebalanceAmount, "ZkBobCompounding: insufficient rebalance"
            );
            investedAssetsAmount = investedAssets + depositAmount;
            IERC4626(yieldAddress).deposit(depositAmount, address(this));
            emit Rebalance(yieldAddress, 0, depositAmount);
        }
    }

    /**
     * @dev Collects accumulated fees and generated yield for the specific collateral.
     * Callable only by the contract owner / proxy admin / yield admin.
     * @param minClaimAmount minimum amount of token to claim.
     * @return Claimed amount.
     */
    function claim(uint256 minClaimAmount) external returns (uint256) {
        (address yieldAddress, address operator, uint256 dust, address interestReceiver) =
            (yieldParams.yield, yieldParams.yieldOperator, yieldParams.dust, yieldParams.interestReceiver);

        require(yieldAddress != address(0), "ZkBobCompounding: yield not enabled");
        require(operator == address(0) || operator == msg.sender || _isOwner(), "ZkBobCompounding: not authorized");

        uint256 claimed = _claim(yieldAddress, interestReceiver, dust);

        require(claimed > 0 && claimed >= minClaimAmount, "ZkBobCompounding: not enough to claim");

        return claimed;
    }


    function _claim(address yieldAddress, address interestReceiver, uint256 dust) internal returns (uint256) {
        uint256 shares = IERC4626(yieldAddress).balanceOf(address(this));
        uint256 lockedAssets = investedAssetsAmount + dust;
        uint256 availableAssets = IERC4626(yieldAddress).convertToAssets(shares);

        if (availableAssets <= lockedAssets) {
            return 0;
        }

        uint256 claimAmount = availableAssets - lockedAssets;
        IERC4626(yieldAddress).withdraw(claimAmount, interestReceiver, address(this));

        emit Claimed(yieldAddress, claimAmount);

        return claimAmount;
    }
}