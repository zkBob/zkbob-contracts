// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IEnergyRedeemer.sol";
import "../interfaces/IZkBobPool.sol";

/**
 * @title EnergyRedeemer
 * Helper for redeeming and distributing result token from the zkBob energy units.
 */
contract EnergyRedeemer is IEnergyRedeemer, Ownable {
    using SafeERC20 for IERC20;

    address public immutable pool;
    address public immutable rewardToken;
    uint256 public immutable base;

    uint96 public initialR;
    uint96 public futureR;
    uint32 public initialRTime;
    uint32 public futureRTime;

    event Redeem(address to, uint256 energy, uint256 redeemed);
    event RampR(uint96 initialR, uint96 futureR, uint32 initialTime, uint32 futureTime);

    constructor(address _pool, address _rewardToken, uint256 _base, uint96 _r) {
        require(uint256(_r) <= type(uint256).max / _base, "EnergyRedeemer: overflow");

        pool = _pool;
        rewardToken = _rewardToken;
        base = _base;
        (initialR, futureR, initialRTime, futureRTime) = (_r, _r, uint32(block.timestamp), uint32(block.timestamp));
    }

    function rampR(uint96 _futureR, uint32 _duration) external onlyOwner {
        require(uint256(_futureR) <= type(uint256).max / base, "EnergyRedeemer: overflow");

        uint96 _initialR = R();
        uint32 t = uint32(block.timestamp);
        (initialR, futureR, initialRTime, futureRTime) = (_initialR, _futureR, t, t + _duration);

        emit RampR(_initialR, _futureR, t, t + _duration);
    }

    function redeem(address _to, uint256 _energy) external {
        require(msg.sender == pool, "EnergyRedeemer: not authorized");

        uint256 redeemAmount = _energy * calculateRedemptionRate() / 1 ether;

        IERC20(rewardToken).safeTransfer(_to, redeemAmount);

        emit Redeem(_to, _energy, redeemAmount);
    }

    function R() public view returns (uint96) {
        (uint96 _initialR, uint96 _futureR, uint32 _initialRTime, uint32 _futureRTime) =
            (initialR, futureR, initialRTime, futureRTime);
        if (block.timestamp < _futureRTime) {
            uint32 dt = uint32(block.timestamp) - _initialRTime;
            uint32 T = _futureRTime - _initialRTime;
            if (_futureR > _initialR) {
                return _initialR + (_futureR - _initialR) * dt / T;
            } else {
                return _initialR - (_initialR - _futureR) * dt / T;
            }
        }
        return _futureR;
    }

    function calculateRedemptionRate() public view returns (uint256) {
        IZkBobAccounting accounting = IZkBobPool(pool).accounting();

        uint256 rate = base * uint256(R());

        (uint256 maxWeeklyAvgTvl, uint256 maxWeeklyTxCount,,,,) = accounting.slot0();

        rate = rate / maxWeeklyAvgTvl;
        rate = rate / maxWeeklyTxCount;

        return rate;
    }

    function maxRedeemAmount() external view returns (uint256) {
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        return balance * 1 ether / calculateRedemptionRate();
    }
}
