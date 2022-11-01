// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "./BaseMinter.sol";

/**
 * @title BalancedMinter
 * BOB minting/burning middleware with simple usage quotas.
 */
contract BalancedMinter is BaseMinter {
    int128 public mintQuota; // remaining minting quota
    int128 public burnQuota; // remaining burning quota

    event UpdateQuotas(int128 mintQuota, int128 burnQuota);

    constructor(address _token, uint128 _mintQuota, uint128 _burnQuota) BaseMinter(_token) {
        mintQuota = int128(_mintQuota);
        burnQuota = int128(_burnQuota);
    }

    /**
     * @dev Adjusts mint/burn quotas for the given address.
     * Callable only by the contract owner.
     * @param _dMint delta for minting quota.
     * @param _dBurn delta for burning quota.
     */
    function adjustQuotas(int128 _dMint, int128 _dBurn) external onlyOwner {
        (int128 newMintQuota, int128 newBurnQuota) = (mintQuota + _dMint, burnQuota + _dBurn);
        (mintQuota, burnQuota) = (newMintQuota, newBurnQuota);

        emit UpdateQuotas(newBurnQuota, newBurnQuota);
    }

    /**
     * @dev Internal function for adjusting quotas on tokens mint.
     * @param _amount amount of minted tokens.
     */
    function _beforeMint(uint256 _amount) internal override {
        int128 amount = int128(uint128(_amount));
        unchecked {
            require(mintQuota >= amount, "BalancedMinter: exceeds minting quota");
            (mintQuota, burnQuota) = (mintQuota - amount, burnQuota + amount);
        }
    }

    /**
     * @dev Internal function for adjusting quotas on tokens burn.
     * @param _amount amount of burnt tokens.
     */
    function _beforeBurn(uint256 _amount) internal override {
        int128 amount = int128(uint128(_amount));
        unchecked {
            require(burnQuota >= amount, "BalancedMinter: exceeds burning quota");
            (mintQuota, burnQuota) = (mintQuota + amount, burnQuota - amount);
        }
    }
}
