// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "forge-std/Test.sol";
import "./shared/Env.t.sol";
import "./shared/EIP2470.t.sol";
import "../src/BobToken.sol";
import "../src/proxy/EIP1967Proxy.sol";
import "./mocks/ERC677Receiver.sol";
import "../src/BobVault.sol";
import "../src/interfaces/ILegacyERC20.sol";
import "../src/yield/AAVEYieldImplementation.sol";

contract BobVaultTest is Test, EIP2470Test {
    EIP1967Proxy bobProxy;
    EIP1967Proxy vaultProxy;
    BobToken bob;
    BobVault vault;

    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    function setUp() public {
        vm.createSelectFork(forkRpcUrl);

        bytes memory creationCode = bytes.concat(type(EIP1967Proxy).creationCode, abi.encode(deployer, mockImpl, ""));
        bobProxy = EIP1967Proxy(factory.deploy(creationCode, bobSalt));
        BobToken impl = new BobToken(address(bobProxy));
        vm.prank(deployer);
        bobProxy.upgradeTo(address(impl));
        bob = BobToken(address(bobProxy));
        vm.prank(deployer);
        bob.updateMinter(deployer, true, true);

        assertEq(address(bobProxy), bobVanityAddr);

        vault = new BobVault(bobVanityAddr);
        vaultProxy = new EIP1967Proxy(deployer, address(vault), "");
        vault = BobVault(address(vaultProxy));

        assertEq(address(vault.bobToken()), address(bob));

        vm.store(address(usdc), keccak256(abi.encode(deployer, uint256(9))), bytes32(uint256(1 ether)));
        vm.store(address(usdt), keccak256(abi.encode(deployer, uint256(2))), bytes32(uint256(1 ether)));
        vm.store(address(dai), keccak256(abi.encode(deployer, uint256(2))), bytes32(uint256(1e12 ether)));

        assertEq(usdc.balanceOf(deployer), 1 ether);
        assertEq(usdt.balanceOf(deployer), 1 ether);
        assertEq(dai.balanceOf(deployer), 1e12 ether);

        vm.startPrank(user1);
        usdc.approve(address(vault), type(uint256).max);
        ILegacyERC20(address(usdt)).approve(address(vault), type(uint256).max);
        dai.approve(address(vault), type(uint256).max);
        bob.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(deployer);
        usdc.approve(address(vault), type(uint256).max);
        ILegacyERC20(address(usdt)).approve(address(vault), type(uint256).max);
        dai.approve(address(vault), type(uint256).max);
        bob.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function _setup3pool(uint256 _bobAmount) internal {
        vm.startPrank(deployer);

        assertEq(vault.isCollateral(address(usdc)), false);
        assertEq(vault.isCollateral(address(usdt)), false);
        assertEq(vault.isCollateral(address(dai)), false);
        vault.addCollateral(address(usdc), BobVault.Collateral(0, 0, 0, address(0), 1000000, 0.001 ether, 0.002 ether));
        vault.addCollateral(address(usdt), BobVault.Collateral(0, 0, 0, address(0), 1000000, 0.003 ether, 0.004 ether));
        vault.addCollateral(address(dai), BobVault.Collateral(0, 0, 0, address(0), 1 ether, 0.005 ether, 0.006 ether));
        assertEq(vault.isCollateral(address(usdc)), true);
        assertEq(vault.isCollateral(address(usdt)), true);
        assertEq(vault.isCollateral(address(dai)), true);

        bob.mint(address(vault), _bobAmount);

        usdc.transfer(user1, 10000000);
        ILegacyERC20(address(usdt)).transfer(user1, 10000000);
        dai.transfer(user1, 10 ether);

        vm.stopPrank();
    }

    function test3pool() public {
        _setup3pool(100 ether);
        vm.startPrank(user1);

        vault.buy(address(usdc), 10000000);
        assertEq(usdc.balanceOf(user1), 0);
        assertEq(usdc.balanceOf(address(vault)), 10000000);
        assertEq(bob.balanceOf(user1), 9.99 ether); // 0.1% inFee

        vault.buy(address(usdt), 10000000);
        assertEq(usdt.balanceOf(user1), 0);
        assertEq(usdt.balanceOf(address(vault)), 10000000);
        assertEq(bob.balanceOf(user1), 9.99 ether + 9.97 ether); // 0.1% inFee + 0.3% inFee

        vault.buy(address(dai), 10 ether);
        assertEq(dai.balanceOf(user1), 0);
        assertEq(dai.balanceOf(address(vault)), 10 ether);
        assertEq(bob.balanceOf(user1), 9.99 ether + 9.97 ether + 9.95 ether); // 0.1% inFee + 0.3% inFee + 0.5% inFee

        vault.sell(address(usdc), 1 ether);
        assertEq(usdc.balanceOf(user1), 998000);
        assertEq(usdc.balanceOf(address(vault)), 9002000);
        assertEq(bob.balanceOf(user1), 8.99 ether + 9.97 ether + 9.95 ether);

        vault.sell(address(usdt), 1 ether);
        assertEq(usdt.balanceOf(user1), 996000);
        assertEq(usdt.balanceOf(address(vault)), 9004000);
        assertEq(bob.balanceOf(user1), 8.99 ether + 8.97 ether + 9.95 ether);

        vault.sell(address(dai), 1 ether);
        assertEq(dai.balanceOf(user1), 0.994 ether);
        assertEq(dai.balanceOf(address(vault)), 9.006 ether);
        assertEq(bob.balanceOf(user1), 8.99 ether + 8.97 ether + 8.95 ether);

        usdc.transfer(address(0xdead), usdc.balanceOf(user1));
        ILegacyERC20(address(usdt)).transfer(address(0xdead), usdt.balanceOf(user1));
        dai.transfer(address(0xdead), dai.balanceOf(user1));

        vm.stopPrank();
        vm.startPrank(deployer);

        uint256 value = 1000000;
        usdc.transfer(user1, value);

        vm.stopPrank();
        vm.startPrank(user1);

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

        vm.startPrank(deployer);
        vault.buy(address(usdc), 1e6 * 1e6);
        vault.buy(address(usdt), 1e6 * 1e6);
        vault.buy(address(dai), 1e6 ether);
        vm.stopPrank();

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
    }

    function testCollateralPause() public {
        _setup3pool(100 ether);

        vm.startPrank(deployer);
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
        vm.stopPrank();

        vm.expectRevert("Ownable: caller is not the owner");
        vault.setCollateralFees(address(usdc), 0.001 ether, 1 ether);
        vm.startPrank(deployer);
        vault.setCollateralFees(address(usdc), 0.001 ether, 1 ether);
        vault.setCollateralFees(address(usdt), 1 ether, 0.004 ether);
        vm.stopPrank();

        vm.startPrank(deployer);
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
        vm.stopPrank();
    }

    function testBalanceAdjustments() public {
        _setup3pool(1000 ether);

        assertEq(vault.getFarmAmount(address(usdc)), 0);
        assertEq(vault.getFarmAmount(address(usdt)), 0);
        assertEq(vault.getFarmAmount(address(dai)), 0);

        vm.startPrank(deployer);
        vault.buy(address(usdc), 100 * 1e6);
        vault.buy(address(usdt), 100 * 1e6);
        vault.buy(address(dai), 100 ether);
        vm.stopPrank();

        assertEq(vault.getFarmAmount(address(usdc)), 0.1 * 1e6);
        assertEq(vault.getFarmAmount(address(usdt)), 0.3 * 1e6);
        assertEq(vault.getFarmAmount(address(dai)), 0.5 ether);

        vm.startPrank(deployer);
        vault.give(address(usdc), 100 * 1e6);
        assertEq(vault.getFarmAmount(address(usdc)), 0.1 * 1e6);
        usdc.transfer(address(vault), 1e6);
        assertEq(vault.getFarmAmount(address(usdc)), 1.1 * 1e6);

        assertGt(bob.balanceOf(address(vault)), 500 ether);
        vault.reclaim(deployer, 1000 ether);
        assertEq(bob.balanceOf(address(vault)), 0);
        vm.stopPrank();
    }

    function testAAVE() public {
        vm.startPrank(deployer);

        vault.setYieldAdmin(user2);

        AAVEYieldImplementation aImpl = new AAVEYieldImplementation(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
        vault.addCollateral(
            address(usdc), BobVault.Collateral(0, 1e6 * 1e6, 1e6, address(aImpl), 1000000, 0.001 ether, 0.002 ether)
        );
        vault.addCollateral(
            address(usdt), BobVault.Collateral(0, 1e6 * 1e6, 1e6, address(aImpl), 1000000, 0.003 ether, 0.004 ether)
        );
        vault.addCollateral(
            address(dai),
            BobVault.Collateral(0, 1e6 * 1 ether, 1 ether, address(aImpl), 1 ether, 0.005 ether, 0.006 ether)
        );

        bob.mint(address(vault), 1e8 ether);

        usdc.transfer(user1, 1e7 * 1e6);
        ILegacyERC20(address(usdt)).transfer(user1, 1e7 * 1e6);
        dai.transfer(user1, 1e7 ether);

        vm.stopPrank();
        vm.startPrank(user1);

        vault.buy(address(usdc), 1e7 * 1e6);
        vault.buy(address(usdt), 1e7 * 1e6);
        vault.buy(address(dai), 1e7 ether);

        vm.stopPrank();
        vm.startPrank(deployer);

        vault.invest(address(usdc));
        vault.invest(address(usdt));
        vault.invest(address(dai));

        assertEq(usdc.balanceOf(address(vault)), 1e6 * 1e6);
        assertEq(usdt.balanceOf(address(vault)), 1e6 * 1e6);
        assertEq(dai.balanceOf(address(vault)), 1e6 ether);

        vm.warp(block.timestamp + 100 days);
        vm.roll(block.number + 100 days / 12 seconds);

        vm.stopPrank();
        vm.startPrank(user2);

        if (usdc.balanceOf(user2) > 0) {
            usdc.transfer(deployer, usdc.balanceOf(user2));
        }
        if (usdt.balanceOf(user2) > 0) {
            ILegacyERC20(address(usdt)).transfer(deployer, usdt.balanceOf(user2));
        }
        if (dai.balanceOf(user2) > 0) {
            dai.transfer(deployer, dai.balanceOf(user2));
        }
        vault.farm(address(usdc));
        vault.farm(address(usdt));
        vault.farm(address(dai));
        assertGt(usdc.balanceOf(user2), 1e6);
        assertGt(usdt.balanceOf(user2), 1e6);
        assertGt(dai.balanceOf(user2), 1 ether);

        vm.stopPrank();
        vm.startPrank(deployer);

        vault.disableCollateralYield(address(usdc));
        vault.disableCollateralYield(address(usdt));
        vault.disableCollateralYield(address(dai));

        vm.stopPrank();
    }
}
