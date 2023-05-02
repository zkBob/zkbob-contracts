// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "forge-std/Test.sol";
import "./shared/Env.t.sol";
import "../src/BobToken.sol";
import "../src/proxy/EIP1967Proxy.sol";
import "./mocks/ERC677Receiver.sol";
import "../src/BobVault.sol";
import "../src/interfaces/ILegacyERC20.sol";
import "../src/yield/AAVEYieldImplementation.sol";
import "./shared/ForkTests.t.sol";

abstract contract AbstractBobVaultTest is Test {
    EIP1967Proxy bobProxy;
    EIP1967Proxy vaultProxy;
    BobToken bob;
    BobVault vault;

    function _setUpBobVault() internal {
        bobProxy = new EIP1967Proxy(address(this), mockImpl, "");
        BobToken bobImpl = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(bobImpl));
        bob = BobToken(address(bobProxy));

        bob.updateMinter(address(this), true, true);

        vault = new BobVault(address(bob));
        vaultProxy = new EIP1967Proxy(address(this), address(vault), "");
        vault = BobVault(address(vaultProxy));

        assertEq(address(vault.bobToken()), address(bob));

        vm.label(address(bob), "BOB");
        vm.label(address(vault), "VAULT");
    }
}

contract BobVaultTest is AbstractBobVaultTest {
    IERC20 tokenA;
    IERC20 tokenB;

    function setUp() public {
        _setUpBobVault();

        tokenA = IERC20(new ERC20Mock("Mock Token A", "MA", address(this), 1_000_000 ether));
        tokenB = IERC20(new ERC20Mock("Mock Token B", "MB", address(this), 1_000_000 ether));
    }

    function testAuthRights() public {
        vm.startPrank(user1);

        vm.expectRevert("Ownable: caller is not the owner");
        vault.addCollateral(
            address(tokenA),
            BobVault.Collateral(
                0, 0, 0, address(0), 1000000, 0.01 ether, 0.01 ether, type(uint128).max, type(uint128).max
            )
        );
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setInvestAdmin(user2);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setYieldAdmin(user2);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setCollateralFees(address(tokenA), 0.01 ether, 0.01 ether);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.enableCollateralYield(address(tokenA), address(0), 1_000_000 * 1e6, 1e6, type(uint128).max);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.disableCollateralYield(address(tokenA));
        vm.expectRevert("Ownable: caller is not the owner");
        vault.updateCollateralYield(address(tokenA), 1_000_000 * 1e6, 1e6, type(uint128).max);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setMaxBalance(address(tokenA), type(uint128).max);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.reclaim(user1, 1e6);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.transferOwnership(user1);
        vm.expectRevert("BobVault: not authorized");
        vault.invest(address(tokenA));
        vm.expectRevert("BobVault: not authorized");
        vault.farm(address(tokenA));
        vm.expectRevert("BobVault: not authorized");
        vault.farmExtra(address(tokenA), "");

        vm.stopPrank();

        vault.setInvestAdmin(user2);
        vault.setYieldAdmin(user3);

        vm.prank(user2);
        vm.expectRevert("BobVault: unsupported collateral");
        vault.invest(address(tokenA));
        vm.prank(user3);
        vm.expectRevert("BobVault: unsupported collateral");
        vault.farm(address(tokenA));
        vm.prank(user3);
        vm.expectRevert("BobVault: unsupported collateral");
        vault.farmExtra(address(tokenA), "");
    }

    function testRoleUpdates() public {
        assertEq(vaultProxy.admin(), address(this));
        assertEq(vault.owner(), address(0));
        assertEq(vault.investAdmin(), address(0));
        assertEq(vault.yieldAdmin(), address(0));

        vault.transferOwnership(user1);
        vault.setInvestAdmin(user2);
        vault.setYieldAdmin(user3);

        assertEq(vaultProxy.admin(), address(this));
        assertEq(vault.owner(), user1);
        assertEq(vault.investAdmin(), user2);
        assertEq(vault.yieldAdmin(), user3);
    }
}

abstract contract AbstractBobVault3poolTest is AbstractBobVaultTest, AbstractForkTest {
    IERC20 usdc;
    IERC20 usdt;
    IERC20 dai;

    function setUp() public {
        vm.createSelectFork(forkRpcUrl, forkBlock);

        _setUpBobVault();

        deal(address(usdc), address(this), 100_000_000 * 1e6);
        deal(address(usdt), address(this), 100_000_000 * 1e6);
        deal(address(dai), address(this), 100_000_000 ether);

        usdc.approve(address(vault), type(uint256).max);
        ILegacyERC20(address(usdt)).approve(address(vault), type(uint256).max);
        dai.approve(address(vault), type(uint256).max);
        bob.approve(address(vault), type(uint256).max);

        vm.startPrank(user1);
        usdc.approve(address(vault), type(uint256).max);
        ILegacyERC20(address(usdt)).approve(address(vault), type(uint256).max);
        dai.approve(address(vault), type(uint256).max);
        bob.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.label(address(usdc), "USDC");
        vm.label(address(usdt), "USDT");
        vm.label(address(dai), "DAI");
    }

    function _setup3pool(uint256 _bobAmount) internal {
        assertEq(vault.isCollateral(address(usdc)), false);
        assertEq(vault.isCollateral(address(usdt)), false);
        assertEq(vault.isCollateral(address(dai)), false);
        vault.addCollateral(
            address(usdc),
            BobVault.Collateral(
                0, 0, 0, address(0), 1e6, 0.001 ether, 0.002 ether, type(uint128).max, type(uint128).max
            )
        );
        vault.addCollateral(
            address(usdt),
            BobVault.Collateral(
                0, 0, 0, address(0), 1e6, 0.003 ether, 0.004 ether, type(uint128).max, type(uint128).max
            )
        );
        vault.addCollateral(
            address(dai),
            BobVault.Collateral(
                0, 0, 0, address(0), 1 ether, 0.005 ether, 0.006 ether, type(uint128).max, type(uint128).max
            )
        );
        assertEq(vault.isCollateral(address(usdc)), true);
        assertEq(vault.isCollateral(address(usdt)), true);
        assertEq(vault.isCollateral(address(dai)), true);

        bob.mint(address(vault), _bobAmount);

        deal(address(usdc), user1, 10 * 1e6);
        deal(address(usdt), user1, 10 * 1e6);
        deal(address(dai), user1, 10 ether);
    }

    function test3pool() public {
        _setup3pool(100 ether);
        vm.startPrank(user1);

        vault.buy(address(usdc), 10 * 1e6);
        assertEq(usdc.balanceOf(user1), 0);
        assertEq(usdc.balanceOf(address(vault)), 10 * 1e6);
        assertEq(bob.balanceOf(user1), 9.99 ether); // 0.1% inFee

        vault.buy(address(usdt), 10 * 1e6);
        assertEq(usdt.balanceOf(user1), 0);
        assertEq(usdt.balanceOf(address(vault)), 10 * 1e6);
        assertEq(bob.balanceOf(user1), 9.99 ether + 9.97 ether); // 0.1% inFee + 0.3% inFee

        vault.buy(address(dai), 10 ether);
        assertEq(dai.balanceOf(user1), 0);
        assertEq(dai.balanceOf(address(vault)), 10 ether);
        assertEq(bob.balanceOf(user1), 9.99 ether + 9.97 ether + 9.95 ether); // 0.1% inFee + 0.3% inFee + 0.5% inFee

        vault.sell(address(usdc), 1 ether);
        assertEq(usdc.balanceOf(user1), 998_000);
        assertEq(usdc.balanceOf(address(vault)), 9_002_000);
        assertEq(bob.balanceOf(user1), 8.99 ether + 9.97 ether + 9.95 ether);

        vault.sell(address(usdt), 1 ether);
        assertEq(usdt.balanceOf(user1), 996_000);
        assertEq(usdt.balanceOf(address(vault)), 9_004_000);
        assertEq(bob.balanceOf(user1), 8.99 ether + 8.97 ether + 9.95 ether);

        vault.sell(address(dai), 1 ether);
        assertEq(dai.balanceOf(user1), 0.994 ether);
        assertEq(dai.balanceOf(address(vault)), 9.006 ether);
        assertEq(bob.balanceOf(user1), 8.99 ether + 8.97 ether + 8.95 ether);

        uint256 value = 1e6;
        deal(address(usdc), user1, value);
        deal(address(usdt), user1, 0);
        deal(address(dai), user1, 0);

        vault.swap(address(usdc), address(usdt), value);

        value = value - value * 0.001 ether / 1 ether;
        value = value - value * 0.004 ether / 1 ether;
        assertEq(usdc.balanceOf(user1), 0);
        assertEq(usdt.balanceOf(user1), value);

        vault.swap(address(usdt), address(dai), value);

        value = value - value * 0.003 ether / 1 ether;
        value *= 1e12;
        value = value - value * 0.006 ether / 1 ether;
        assertEq(usdt.balanceOf(user1), 0);
        assertEq(dai.balanceOf(user1), value);

        vault.swap(address(dai), address(usdc), value);

        value = value - value * 0.005 ether / 1 ether;
        value /= 1e12;
        value = value - value * 0.002 ether / 1 ether;
        assertEq(dai.balanceOf(user1), 0);
        assertEq(usdc.balanceOf(user1), value);
        vm.stopPrank();
    }

    function testAmountEstimation() public {
        _setup3pool(1e9 ether);

        // collateral -> bob
        assertEq(vault.getAmountOut(address(usdc), address(bob), 100 * 1e6), 99.9 ether);
        assertEq(vault.getAmountIn(address(usdc), address(bob), 99.9 ether), 100 * 1e6);
        assertEq(vault.getAmountOut(address(usdt), address(bob), 100 * 1e6), 99.7 ether);
        assertEq(vault.getAmountIn(address(usdt), address(bob), 99.7 ether), 100 * 1e6);
        assertEq(vault.getAmountOut(address(dai), address(bob), 100 ether), 99.5 ether);
        assertEq(vault.getAmountIn(address(dai), address(bob), 99.5 ether), 100 ether);
        vm.expectRevert("BobVault: exceeds available liquidity");
        vault.getAmountOut(address(usdc), address(bob), 1e18 * 1e6);
        vm.expectRevert("BobVault: exceeds available liquidity");
        vault.getAmountIn(address(usdc), address(bob), 1e18 ether);

        vault.buy(address(usdc), 1_000_000 * 1e6);
        vault.buy(address(usdt), 1_000_000 * 1e6);
        vault.buy(address(dai), 1_000_000 ether);

        // bob -> collateral
        assertEq(vault.getAmountOut(address(bob), address(usdc), 100 ether), 99.8 * 1e6);
        assertEq(vault.getAmountIn(address(bob), address(usdc), 99.8 * 1e6), 100 ether);
        assertEq(vault.getAmountOut(address(bob), address(usdt), 100 ether), 99.6 * 1e6);
        assertEq(vault.getAmountIn(address(bob), address(usdt), 99.6 * 1e6), 100 ether);
        assertEq(vault.getAmountOut(address(bob), address(dai), 100 ether), 99.4 ether);
        assertEq(vault.getAmountIn(address(bob), address(dai), 99.4 ether), 100 ether);
        vm.expectRevert("BobVault: insufficient liquidity for collateral");
        vault.getAmountOut(address(bob), address(usdc), 1e18 ether);
        vm.expectRevert("BobVault: insufficient liquidity for collateral");
        vault.getAmountIn(address(bob), address(usdc), 1e18 * 1e6);

        assertEq(vault.stat(address(usdc)).required, 1_000_000 * 1e6 * 0.999);
        vm.expectRevert("BobVault: insufficient liquidity for collateral");
        vault.getAmountIn(address(bob), address(usdc), 1_000_000 * 1e6 * 0.999 * 0.998 + 1);
        vault.getAmountIn(address(bob), address(usdc), 1_000_000 * 1e6 * 0.999 * 0.998);

        // collateral -> collateral
        assertEq(vault.getAmountOut(address(usdc), address(usdt), 100 * 1e6), 99_500_400); // 0.1% + 0.4%
        assertEq(vault.getAmountIn(address(usdc), address(usdt), 99_500_400), 100 * 1e6); // 0.1% + 0.4%
        assertEq(vault.getAmountOut(address(usdc), address(dai), 100 * 1e6), 99_300_600 * 1e12); // 0.1% + 0.6%
        assertEq(vault.getAmountIn(address(usdc), address(dai), 99_300_600 * 1e12), 100 * 1e6); // 0.1% + 0.6%
        assertEq(vault.getAmountOut(address(usdt), address(usdc), 100 * 1e6), 99_500_600); // 0.3% + 0.2%
        assertEq(vault.getAmountIn(address(usdt), address(usdc), 99_500_600), 100 * 1e6); // 0.3% + 0.2%
        assertEq(vault.getAmountOut(address(usdt), address(dai), 100 * 1e6), 99_101_800 * 1e12); // 0.3% + 0.6%
        assertEq(vault.getAmountIn(address(usdt), address(dai), 99_101_800 * 1e12), 100 * 1e6); // 0.3% + 0.6%
        assertEq(vault.getAmountOut(address(dai), address(usdc), 100 ether), 99_301_000); // 0.5% + 0.2%
        assertEq(vault.getAmountIn(address(dai), address(usdc), 99_301_000), 100 ether); // 0.5% + 0.2%
        assertEq(vault.getAmountOut(address(dai), address(usdt), 100 ether), 99_102_000); // 0.5% + 0.4%
        assertEq(vault.getAmountIn(address(dai), address(usdt), 99_102_000), 100 ether); // 0.5% + 0.4%
        vm.expectRevert("BobVault: insufficient liquidity for collateral");
        vault.getAmountOut(address(usdc), address(usdt), 1 ether);
        vm.expectRevert("BobVault: insufficient liquidity for collateral");
        vault.getAmountIn(address(usdt), address(usdc), 1 ether);

        assertEq(vault.stat(address(usdc)).required, 1_000_000 * 1e6 * 0.999);
        vm.expectRevert("BobVault: insufficient liquidity for collateral");
        vault.getAmountIn(address(usdt), address(usdc), 1_000_000 * 1e6 * 0.999 * 0.998 + 1);
        vault.getAmountIn(address(usdt), address(usdc), 1_000_000 * 1e6 * 0.999 * 0.998);
    }

    function testCollateralPause() public {
        _setup3pool(100 ether);

        vault.buy(address(usdc), 10 * 1e6);
        vault.buy(address(usdt), 10 * 1e6);
        vault.buy(address(dai), 10 ether);
        vault.sell(address(usdc), 1 ether);
        vault.sell(address(usdt), 1 ether);
        vault.sell(address(dai), 1 ether);
        vault.swap(address(usdc), address(usdt), 1e6);
        vault.swap(address(usdc), address(dai), 1e6);
        vault.swap(address(usdt), address(usdc), 1e6);
        vault.swap(address(usdt), address(dai), 1e6);
        vault.swap(address(dai), address(usdc), 1 ether);
        vault.swap(address(dai), address(usdt), 1 ether);

        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setCollateralFees(address(usdc), 0.001 ether, 1 ether);
        vault.setCollateralFees(address(usdc), 0.001 ether, 1 ether);
        vault.setCollateralFees(address(usdt), 1 ether, 0.004 ether);

        vault.buy(address(usdc), 10 * 1e6);
        vm.expectRevert("BobVault: collateral deposit suspended");
        vault.buy(address(usdt), 10 * 1e6);
        vault.buy(address(dai), 10 ether);
        vm.expectRevert("BobVault: collateral withdrawal suspended");
        vault.sell(address(usdc), 1 ether);
        vault.sell(address(usdt), 1 ether);
        vault.sell(address(dai), 1 ether);
        vault.swap(address(usdc), address(usdt), 1e6);
        vault.swap(address(usdc), address(dai), 1e6);
        vm.expectRevert("BobVault: collateral deposit suspended");
        vault.swap(address(usdt), address(usdc), 1e6);
        vm.expectRevert("BobVault: collateral deposit suspended");
        vault.swap(address(usdt), address(dai), 1e6);
        vm.expectRevert("BobVault: collateral withdrawal suspended");
        vault.swap(address(dai), address(usdc), 1 ether);
        vault.swap(address(dai), address(usdt), 1 ether);
    }

    function testBalanceAdjustments() public {
        _setup3pool(1000 ether);

        assertEq(vault.stat(address(usdc)).farmed, 0);
        assertEq(vault.stat(address(usdt)).farmed, 0);
        assertEq(vault.stat(address(dai)).farmed, 0);

        vault.buy(address(usdc), 100 * 1e6);
        vault.buy(address(usdt), 100 * 1e6);
        vault.buy(address(dai), 100 ether);

        assertEq(vault.stat(address(usdc)).farmed, 0.1 * 1e6);
        assertEq(vault.stat(address(usdt)).farmed, 0.3 * 1e6);
        assertEq(vault.stat(address(dai)).farmed, 0.5 ether);

        vault.give(address(usdc), 100 * 1e6);
        assertEq(vault.stat(address(usdc)).farmed, 0.1 * 1e6);
        usdc.transfer(address(vault), 1e6);
        assertEq(vault.stat(address(usdc)).farmed, 1.1 * 1e6);

        assertGt(bob.balanceOf(address(vault)), 700 ether);
        assertEq(bob.balanceOf(user1), 0);
        vault.reclaim(user1, 1000 ether);
        assertEq(bob.balanceOf(address(vault)), 0);
        assertGt(bob.balanceOf(user1), 700 ether);
    }

    function testMaxBalance() public {
        _setup3pool(100 ether);

        vm.expectRevert("BobVault: unsupported collateral");
        vault.setMaxBalance(address(this), 50 * 1e6);

        vault.setMaxBalance(address(usdc), 50 * 1e6);

        vault.buy(address(usdc), 30 * 1e6);
        vault.buy(address(usdt), 30 * 1e6);

        vm.expectRevert("BobVault: exceeds max balance");
        vault.getAmountOut(address(usdc), address(bob), 25 * 1e6);
        vm.expectRevert("BobVault: exceeds max balance");
        vault.getAmountIn(address(usdc), address(bob), 25 ether);
        vm.expectRevert("BobVault: exceeds max balance");
        vault.buy(address(usdc), 25 * 1e6);

        vm.expectRevert("BobVault: exceeds max balance");
        vault.getAmountOut(address(usdc), address(usdt), 25 * 1e6);
        vm.expectRevert("BobVault: exceeds max balance");
        vault.getAmountIn(address(usdc), address(usdt), 25 * 1e6);
        vm.expectRevert("BobVault: exceeds max balance");
        vault.swap(address(usdc), address(usdt), 25 * 1e6);

        assertEq(vault.getAmountOut(address(usdc), address(bob), 20 * 1e6), 19.98 ether);
        assertEq(vault.getAmountIn(address(usdc), address(bob), 19.98 ether), 20 * 1e6);
        vault.buy(address(usdc), 20 * 1e6);
        vm.expectRevert("BobVault: exceeds max balance");
        vault.swap(address(usdc), address(usdt), 20 * 1e6);

        vault.sell(address(usdc), 20 ether);
        assertEq(vault.getAmountOut(address(usdc), address(usdt), 20 * 1e6), 20 * 1e6 * 0.999 * 0.996);
        assertEq(vault.getAmountIn(address(usdc), address(usdt), 20 * 1e6 * 0.999 * 0.996), 20 * 1e6);
        vault.swap(address(usdc), address(usdt), 20 * 1e6);

        BobVault.Stat memory stat = vault.stat(address(usdc));
        assertEq(stat.required, 50 * 1e6 - 70 * 1e6 * 0.001);
    }
}

abstract contract AbstractBobVaultAAVETest is AbstractBobVaultTest, AbstractForkTest {
    IERC20 usdc;
    IERC20 usdt;
    IERC20 dai;

    address lendingPool;

    function setUp() public {
        vm.createSelectFork(forkRpcUrl, forkBlock);

        _setUpBobVault();

        deal(address(usdc), address(this), 100_000_000 * 1e6);
        deal(address(usdt), address(this), 100_000_000 * 1e6);
        deal(address(dai), address(this), 100_000_000 ether);

        usdc.approve(address(vault), type(uint256).max);
        ILegacyERC20(address(usdt)).approve(address(vault), type(uint256).max);
        dai.approve(address(vault), type(uint256).max);
        bob.approve(address(vault), type(uint256).max);

        vm.startPrank(user1);
        usdc.approve(address(vault), type(uint256).max);
        ILegacyERC20(address(usdt)).approve(address(vault), type(uint256).max);
        dai.approve(address(vault), type(uint256).max);
        bob.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.label(address(usdc), "USDC");
        vm.label(address(usdt), "USDT");
        vm.label(address(dai), "DAI");
    }

    function _setupAAVEYieldForUSDC() internal {
        vault.setYieldAdmin(user2);

        AAVEYieldImplementation aImpl = new AAVEYieldImplementation(lendingPool);
        vault.addCollateral(
            address(usdc),
            BobVault.Collateral(
                0,
                1_000_000 * 1e6,
                1e6,
                address(aImpl),
                1e6,
                0.001 ether,
                0.002 ether,
                type(uint128).max,
                type(uint128).max
            )
        );

        bob.mint(address(vault), 100_000_000 ether);

        deal(address(usdc), user1, 10_000_000 * 1e6);
        vm.prank(user1);
        vault.buy(address(usdc), 10_000_000 * 1e6);

        vault.invest(address(usdc));

        vm.warp(block.timestamp + 100 days);
        vm.roll(block.number + 100 days / 12 seconds);

        assertEq(usdc.balanceOf(address(vault)), 1_000_000 * 1e6);
    }

    function testAAVEIntegration() public {
        vault.setYieldAdmin(user2);

        AAVEYieldImplementation aImpl = new AAVEYieldImplementation(lendingPool);
        vault.addCollateral(
            address(usdc),
            BobVault.Collateral(
                0,
                1_000_000 * 1e6,
                1e6,
                address(aImpl),
                1e6,
                0.001 ether,
                0.002 ether,
                type(uint128).max,
                type(uint128).max
            )
        );
        vault.addCollateral(
            address(usdt),
            BobVault.Collateral(
                0,
                1_000_000 * 1e6,
                1e6,
                address(aImpl),
                1e6,
                0.003 ether,
                0.004 ether,
                type(uint128).max,
                type(uint128).max
            )
        );
        vault.addCollateral(
            address(dai),
            BobVault.Collateral(
                0,
                1_000_000 ether,
                1 ether,
                address(aImpl),
                1 ether,
                0.005 ether,
                0.006 ether,
                type(uint128).max,
                type(uint128).max
            )
        );

        bob.mint(address(vault), 100_000_000 ether);

        deal(address(usdc), user1, 10_000_000 * 1e6);
        deal(address(usdt), user1, 10_000_000 * 1e6);
        deal(address(dai), user1, 10_000_000 ether);

        vm.startPrank(user1);

        vault.buy(address(usdc), 10_000_000 * 1e6);
        vault.buy(address(usdt), 10_000_000 * 1e6);
        vault.buy(address(dai), 10_000_000 ether);

        vm.stopPrank();

        vault.invest(address(usdc));
        vault.invest(address(usdt));
        vault.invest(address(dai));

        assertEq(usdc.balanceOf(address(vault)), 1_000_000 * 1e6);
        assertEq(usdt.balanceOf(address(vault)), 1_000_000 * 1e6);
        assertEq(dai.balanceOf(address(vault)), 1_000_000 ether);

        vm.warp(block.timestamp + 100 days);
        vm.roll(block.number + 100 days / 12 seconds);

        vm.startPrank(user2);

        deal(address(usdc), user2, 0);
        deal(address(usdt), user2, 0);
        deal(address(dai), user2, 0);

        vault.farm(address(usdc));
        vault.farm(address(usdt));
        vault.farm(address(dai));
        assertGt(usdc.balanceOf(user2), 1e6);
        assertGt(usdt.balanceOf(user2), 1e6);
        assertGt(dai.balanceOf(user2), 1 ether);
        vm.expectRevert("YieldConnector: delegatecall failed");
        vault.farmExtra(address(usdc), "");

        vm.stopPrank();

        vault.disableCollateralYield(address(usdc));
        vault.disableCollateralYield(address(usdt));
        vault.disableCollateralYield(address(dai));

        assertEq(_getAToken(address(usdc)).balanceOf(address(vault)), 0);
        assertEq(_getAToken(address(usdt)).balanceOf(address(vault)), 0);
        assertEq(_getAToken(address(dai)).balanceOf(address(vault)), 0);
    }

    function testAAVEYieldParamsUpdates() public {
        _setupAAVEYieldForUSDC();

        BobVault.Stat memory stat = vault.stat(address(usdc));
        assertGt(stat.total, 10_000_002 * 1e6);
        assertEq(stat.required, 9_990_001 * 1e6);
        assertGt(stat.farmed, 10_001 * 1e6);

        uint256 investedAmount1 = _getAToken(address(usdc)).balanceOf(address(vault));
        assertGt(investedAmount1, 0);

        vault.updateCollateralYield(address(usdc), 100_000 * 1e6, 10 * 1e6, type(uint128).max);

        uint256 investedAmount2 = _getAToken(address(usdc)).balanceOf(address(vault));
        assertGt(investedAmount2, investedAmount1);

        assertEq(usdc.balanceOf(address(vault)), 100_000 * 1e6);

        stat = vault.stat(address(usdc));
        assertGt(stat.total, 10_000_002 * 1e6);
        assertEq(stat.required, 9_990_010 * 1e6);
        assertGt(stat.farmed, 10_001 * 1e6);

        vault.disableCollateralYield(address(usdc));

        stat = vault.stat(address(usdc));
        assertGt(stat.total, 10_000_002 * 1e6);
        assertEq(stat.required, 9_990_000 * 1e6);
        assertGt(stat.farmed, 10_001 * 1e6);

        vm.startPrank(user2);

        deal(address(usdc), user2, 0);
        vault.farm(address(usdc));
        assertGt(usdc.balanceOf(user2), 1e6);

        vm.stopPrank();

        assertEq(_getAToken(address(usdc)).balanceOf(address(vault)), 0);
    }

    function testAAVEYieldEnabling() public {
        _setupAAVEYieldForUSDC();

        BobVault.Stat memory stat = vault.stat(address(usdc));
        assertGt(stat.total, 10_000_002 * 1e6);
        assertEq(stat.required, 9_990_001 * 1e6);
        assertGt(stat.farmed, 10_001 * 1e6);
        assertEq(usdc.balanceOf(address(vault)), 1_000_000 * 1e6);
        assertGt(_getAToken(address(usdc)).balanceOf(address(vault)), 9_000_000 * 1e6);

        vault.disableCollateralYield(address(usdc));

        stat = vault.stat(address(usdc));
        assertGt(stat.total, 10_000_002 * 1e6);
        assertEq(stat.required, 9_990_000 * 1e6);
        assertGt(stat.farmed, 10_001 * 1e6);
        assertGt(usdc.balanceOf(address(vault)), 10_000_000 * 1e6);
        assertEq(_getAToken(address(usdc)).balanceOf(address(vault)), 0);

        address aImpl = address(new AAVEYieldImplementation(lendingPool));
        vault.enableCollateralYield(address(usdc), aImpl, 100_000 * 1e6, 10 * 1e6, type(uint128).max);

        stat = vault.stat(address(usdc));
        assertGt(stat.total, 10_000_002 * 1e6);
        assertEq(stat.required, 9_990_010 * 1e6);
        assertGt(stat.farmed, 10_001 * 1e6);
        assertEq(usdc.balanceOf(address(vault)), 100_000 * 1e6);
        assertGt(_getAToken(address(usdc)).balanceOf(address(vault)), 9_900_000 * 1e6);
    }

    function testAAVEWithdrawalOnDemand() public {
        _setupAAVEYieldForUSDC();

        BobVault.Stat memory stat = vault.stat(address(usdc));
        assertGt(stat.total, 10_000_000 * 1e6);
        assertEq(usdc.balanceOf(address(vault)), 1_000_000 * 1e6);

        vm.prank(user1);
        vault.sell(address(usdc), 100_000 ether);

        stat = vault.stat(address(usdc));
        assertGt(stat.total, 9_900_000 * 1e6);
        assertEq(usdc.balanceOf(address(vault)), 900_200 * 1e6);

        vm.prank(user1);
        vault.sell(address(usdc), 1_100_000 ether);

        stat = vault.stat(address(usdc));
        assertGt(stat.total, 8_800_000 * 1e6);
        assertEq(usdc.balanceOf(address(vault)), 1_000_000 * 1e6);

        vm.prank(user1);
        vault.sell(address(usdc), 8_000_000 ether);

        stat = vault.stat(address(usdc));
        assertGt(stat.total, 800_000 * 1e6);
        assertGt(usdc.balanceOf(address(vault)), 800_000 * 1e6);
        assertLt(usdc.balanceOf(address(vault)), 900_000 * 1e6);

        assertEq(_getAToken(address(usdc)).balanceOf(address(vault)), 0);
    }

    function testAAVEMaxInvested() public {
        _setupAAVEYieldForUSDC();

        vault.updateCollateralYield(address(usdc), 1_000_000 * 1e6, 1e6, 2_000_000 * 1e6);
        assertGt(_getAToken(address(usdc)).balanceOf(address(vault)), 9_000_000 * 1e6);

        vm.prank(user1);
        vault.sell(address(usdc), 9_000_000 ether);
        vm.prank(user1);
        vault.buy(address(usdc), 4_000_000 * 1e6);

        vault.invest(address(usdc));

        assertApproxEqAbs(_getAToken(address(usdc)).balanceOf(address(vault)), 2_000_000 * 1e6, 1000);
    }

    function _getAToken(address _token) internal returns (IERC20) {
        uint256[12] memory reserveData = ILendingPool(lendingPool).getReserveData(_token);
        // 7th slot for AAVE v2, 8th slot for AAVE v3
        address aToken = address(uint160(reserveData[reserveData[7] <= type(uint16).max ? 8 : 7]));

        return IERC20(aToken);
    }
}

contract BobVault3PoolTest is AbstractBobVault3poolTest, AbstractMainnetForkTest {
    constructor() {
        usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    }
}

contract BobVaultAAVEv2MainnetTest is AbstractBobVaultAAVETest, AbstractMainnetForkTest {
    constructor() {
        usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

        lendingPool = address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    }
}

contract BobVaultAAVEv2PolygonTest is AbstractBobVaultAAVETest, AbstractPolygonForkTest {
    constructor() {
        usdc = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        usdt = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
        dai = IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);

        lendingPool = address(0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf);
    }
}

contract BobVaultAAVEv3PolygonTest is AbstractBobVaultAAVETest, AbstractPolygonForkTest {
    constructor() {
        usdc = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        usdt = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
        dai = IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);

        lendingPool = address(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    }
}

contract BobVaultAAVEv3OptimismTest is AbstractBobVaultAAVETest, AbstractOptimismForkTest {
    constructor() {
        usdc = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
        usdt = IERC20(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);
        dai = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);

        lendingPool = address(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    }
}
