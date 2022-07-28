// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/proxy/EIP1967Proxy.sol";
import "./mocks/DummyImpl.sol";

contract EIP1967Test is Test {
    address user1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address user2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    function testSimpleProxyCreation() public {
        DummyImpl impl = new DummyImpl(1);
        EIP1967Proxy proxy = new EIP1967Proxy(address(this), address(impl));
        DummyImpl target = DummyImpl(address(proxy));

        assertEq(target.value(), 0);
        assertEq(target.const(), 1);
        target.increment();
        assertEq(target.value(), 1);
        assertEq(target.const(), 1);
    }

    function testSimpleProxyUpgrade() public {
        DummyImpl impl = new DummyImpl(1);
        EIP1967Proxy proxy = new EIP1967Proxy(address(this), address(impl));
        DummyImpl target = DummyImpl(address(proxy));

        target.increment();

        impl = new DummyImpl(2);

        assertEq(target.value(), 1);
        assertEq(target.const(), 1);
        proxy.upgradeTo(address(impl));
        assertEq(target.value(), 1);
        assertEq(target.const(), 2);
        target.increment();
        assertEq(target.value(), 2);
        assertEq(target.const(), 2);
    }

    function testProxyAccessRights() public {
        DummyImpl impl = new DummyImpl(1);
        EIP1967Proxy proxy = new EIP1967Proxy(address(this), address(impl));

        impl = new DummyImpl(2);
        vm.prank(user1);
        vm.expectRevert();
        proxy.upgradeTo(address(impl));
    }

    function testProxyUpgradeAndCall() public {
        EIP1967Proxy proxy = new EIP1967Proxy(address(this), address(0xdead));
        DummyImpl impl = new DummyImpl(1);

        proxy.upgradeToAndCall(address(impl), abi.encodeWithSelector(DummyImpl.increment.selector));
        DummyImpl target = DummyImpl(address(proxy));
        assertEq(target.value(), 1);
        assertEq(target.const(), 1);
    }
}
