// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "../../src/zkbob/ZkBobPool.sol";

contract SetManagerAndTierLimits is Script {
    uint256 internal constant MAX_DENOMINATOR = 0x8000000000000000000000000000000000000000000000000000000000000000 - 1;

    function tokenToPool(uint256 _value, uint256 _denominator) internal pure returns (uint64) {
        if (_denominator <= MAX_DENOMINATOR) {
            return uint64(_value / _denominator);
        } else {
            return uint64(_value * (_denominator & MAX_DENOMINATOR));
        }
    }

    function poolToToken(uint256 _value, uint256 _denominator) internal pure returns (uint256) {
        if (_denominator <= MAX_DENOMINATOR) {
            return _value * _denominator;
        } else {
            return _value / (_denominator & MAX_DENOMINATOR);
        }
    }

    function run() external {
        ZkBobPool pool = ZkBobPool(0x49661694a71B3Dab9F25E86D5df2809B170c56E6); // Goerli, BOB->USDC pool
        // ZkBobPool pool = ZkBobPool(0xCF6446Deb67b2b56604657C67DAF54f884412531);  // Goerli, USDC pool
        IKycProvidersManager kyc_mgr = IKycProvidersManager(0x2C34aFcB1c51796c3c0C7710c72a56Eb72E1E81D);
        address user = address(0xBF3d6f830CE263CAE987193982192Cd990442B53);
        address owner = address(0x39F0bD56c1439a22Ee90b4972c16b7868D161981);

        ZkBobPool.Limits memory limits_prev;
        ZkBobPool.Limits memory limits_new;

        uint256 denominator = pool.denominator();        
        limits_prev = pool.getLimitsFor(user);

        // vm.startPrank(owner);
        vm.startBroadcast();

        pool.setLimits({
            _tier: 254,
            _tvlCap: poolToToken(limits_prev.tvlCap, denominator),
            _dailyDepositCap: poolToToken(limits_prev.dailyDepositCap, denominator),
            _dailyWithdrawalCap: poolToToken(limits_prev.dailyWithdrawalCap, denominator),
            _dailyUserDepositCap: poolToToken(limits_prev.dailyUserDepositCap, denominator) * 2,
            _depositCap: poolToToken(limits_prev.depositCap, denominator) * 2,
            _dailyUserDirectDepositCap: poolToToken(limits_prev.dailyUserDirectDepositCap, denominator),
            _directDepositCap: poolToToken(limits_prev.directDepositCap, denominator)
        });

        pool.setKycProvidersManager(kyc_mgr);

        vm.stopBroadcast();
        // vm.stopPrank();

        require(pool.kycProvidersManager() == kyc_mgr, "Incorrect KYC Provider Manager");

        limits_new = pool.getLimitsFor(user);
        require((limits_new.tvlCap == limits_prev.tvlCap) && (limits_new.dailyWithdrawalCap == limits_prev.dailyWithdrawalCap), "Incorrect limits");
        require((limits_new.dailyUserDepositCap == 2 * limits_prev.dailyUserDepositCap) && (limits_new.depositCap == 2 * limits_prev.depositCap), "Incorrect KYC limits");
    }
}
