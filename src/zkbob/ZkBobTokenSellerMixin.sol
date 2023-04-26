// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ZkBobPool.sol";

/**
 * @title ZkBobTokenSellerMixin
 */
abstract contract ZkBobTokenSellerMixin is ZkBobPool {
    using SafeERC20 for IERC20;

    ITokenSeller public tokenSeller;

    event UpdateTokenSeller(address seller);

    /**
     * @dev Updates token seller contract used for native coin withdrawals.
     * Callable only by the contract owner / proxy admin.
     * @param _seller new token seller contract implementation. address(0) will deactivate native withdrawals.
     */
    function setTokenSeller(address _seller) external onlyOwner {
        tokenSeller = ITokenSeller(_seller);
        emit UpdateTokenSeller(_seller);
    }

    // @inheritdoc ZkBobPool
    function _withdrawNative(address _user, uint256 _tokenAmount) internal override returns (uint256) {
        ITokenSeller seller = tokenSeller;
        if (address(seller) != address(0)) {
            IERC20(token).safeTransfer(address(seller), _tokenAmount);
            (, uint256 refunded) = seller.sellForETH(_user, _tokenAmount);
            return _tokenAmount - refunded;
        }
        return 0;
    }
}
