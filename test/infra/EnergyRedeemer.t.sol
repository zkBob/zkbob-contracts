// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "../shared/Env.t.sol";
import "../../src/interfaces/IEnergyRedeemer.sol";
import "../../src/infra/EnergyRedeemer.sol";
import "../mocks/ZkBobAccountingMock.sol";

contract EnergyRedeemerTest is Test {
    ZkBobAccountingMock pool;
    IERC20 rewardToken;
    EnergyRedeemer redeemer;

    event Redeem(address to, uint256 energy, uint256 redeemed);
    event RampR(uint96 initialR, uint96 futureR, uint32 initialTime, uint32 futureTime);

    function setUp() public {
        pool = new ZkBobAccountingMock(1e6, 1e4);
        rewardToken = IERC20(new ERC20Mock("Reward token", "RT", address(this), 1_000_000 ether));
        redeemer = new EnergyRedeemer(address(pool), address(rewardToken), 1e13, 1e12);
        rewardToken.transfer(address(redeemer), 1_000_000 ether);
    }

    function testGetters() public {
        assertEq(redeemer.R(), 1e12);
        assertEq(redeemer.calculateRedemptionRate(), 1e15); // 1e13 * 1e12 / 1e6 / 1e4
        assertEq(redeemer.maxRedeemAmount(), 1_000_000_000 ether);
    }

    function testRedeem() public {
        assertEq(redeemer.maxRedeemAmount(), 1_000_000_000 ether);

        vm.expectRevert("EnergyRedeemer: not authorized");
        redeemer.redeem(user1, 1_000 ether);
        pool.redeem(address(redeemer), user1, 1_000 ether);

        assertEq(rewardToken.balanceOf(user1), 1 ether);
        assertEq(redeemer.maxRedeemAmount(), 999_999_000 ether);
    }

    function testRampSimple() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        redeemer.rampR(1e13, 0);

        assertEq(redeemer.R(), 1e12);
        assertEq(redeemer.calculateRedemptionRate(), 1e15); // 1e13 * 1e12 / 1e6 / 1e4
        assertEq(redeemer.maxRedeemAmount(), 1_000_000_000 ether);

        redeemer.rampR(1e13, 0);

        assertEq(redeemer.R(), 1e13);
        assertEq(redeemer.calculateRedemptionRate(), 1e16); // 1e13 * 1e13 / 1e6 / 1e4
        assertEq(redeemer.maxRedeemAmount(), 100_000_000 ether);

        redeemer.rampR(1e11, 0);

        assertEq(redeemer.R(), 1e11);
        assertEq(redeemer.calculateRedemptionRate(), 1e14); // 1e13 * 1e11 / 1e6 / 1e4
        assertEq(redeemer.maxRedeemAmount(), 10_000_000_000 ether);
    }

    function testRampUp() public {
        assertEq(redeemer.R(), 1e12);
        assertEq(redeemer.calculateRedemptionRate(), 1e15); // 1e13 * 1e12 / 1e6 / 1e4
        assertEq(redeemer.maxRedeemAmount(), 1_000_000_000 ether);

        redeemer.rampR(1e13, 9 days);

        assertEq(redeemer.R(), 1e12);
        assertEq(redeemer.calculateRedemptionRate(), 1e15); // 1e13 * 1e12 / 1e6 / 1e4
        assertEq(redeemer.maxRedeemAmount(), 1_000_000_000 ether);

        skip(4 days);

        assertEq(redeemer.R(), 5e12);
        assertEq(redeemer.calculateRedemptionRate(), 5e15); // 1e13 * 5e12 / 1e6 / 1e4
        assertEq(redeemer.maxRedeemAmount(), 200_000_000 ether);

        skip(10 days);

        assertEq(redeemer.R(), 1e13);
        assertEq(redeemer.calculateRedemptionRate(), 1e16); // 1e13 * 1e13 / 1e6 / 1e4
        assertEq(redeemer.maxRedeemAmount(), 100_000_000 ether);
    }

    function testRampDown() public {
        assertEq(redeemer.R(), 1e12);
        assertEq(redeemer.calculateRedemptionRate(), 1e15); // 1e13 * 1e12 / 1e6 / 1e4
        assertEq(redeemer.maxRedeemAmount(), 1_000_000_000 ether);

        redeemer.rampR(1e11, 9 days);

        assertEq(redeemer.R(), 1e12);
        assertEq(redeemer.calculateRedemptionRate(), 1e15); // 1e13 * 1e12 / 1e6 / 1e4
        assertEq(redeemer.maxRedeemAmount(), 1_000_000_000 ether);

        skip(5 days);

        assertEq(redeemer.R(), 5e11);
        assertEq(redeemer.calculateRedemptionRate(), 5e14); // 1e13 * 5e11 / 1e6 / 1e4
        assertEq(redeemer.maxRedeemAmount(), 2_000_000_000 ether);

        skip(10 days);

        assertEq(redeemer.R(), 1e11);
        assertEq(redeemer.calculateRedemptionRate(), 1e14); // 1e13 * 1e11 / 1e6 / 1e4
        assertEq(redeemer.maxRedeemAmount(), 10_000_000_000 ether);
    }
}
