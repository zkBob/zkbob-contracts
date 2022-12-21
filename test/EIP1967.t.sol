// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "./shared/Env.t.sol";
import "../src/proxy/EIP1967Proxy.sol";
import "./mocks/DummyImpl.sol";

contract EIP1967Test is Test {
    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);

    function testSimpleProxyCreation() public {
        DummyImpl impl = new DummyImpl(1);
        EIP1967Proxy proxy = new EIP1967Proxy(address(this), address(impl), "");
        DummyImpl target = DummyImpl(address(proxy));

        assertEq(target.value(), 0);
        assertEq(target.const(), 1);
        target.increment();
        assertEq(target.value(), 1);
        assertEq(target.const(), 1);

        assertEq(proxy.admin(), address(this));
        assertEq(proxy.implementation(), address(impl));
    }

    function testProxyInitializaion() public {
        DummyImpl impl = new DummyImpl(1);

        vm.expectEmit(false, false, false, true);
        emit AdminChanged(address(0), address(this));
        vm.expectEmit(true, false, false, true);
        emit Upgraded(address(impl));
        EIP1967Proxy proxy =
            new EIP1967Proxy(address(this), address(impl), abi.encodeWithSelector(DummyImpl.initialize.selector));

        DummyImpl target = DummyImpl(address(proxy));

        assertEq(target.value(), 1);
        assertEq(target.const(), 1);
    }

    function testSimpleProxyUpgrade() public {
        DummyImpl impl = new DummyImpl(1);
        EIP1967Proxy proxy = new EIP1967Proxy(address(this), address(impl), "");
        DummyImpl target = DummyImpl(address(proxy));

        target.increment();

        DummyImpl newImpl = new DummyImpl(2);

        assertEq(target.value(), 1);
        assertEq(target.const(), 1);

        assertEq(proxy.implementation(), address(impl));
        vm.expectEmit(true, false, false, true);
        emit Upgraded(address(newImpl));
        proxy.upgradeTo(address(newImpl));
        assertEq(proxy.implementation(), address(newImpl));

        assertEq(target.value(), 1);
        assertEq(target.const(), 2);
        target.increment();
        assertEq(target.value(), 2);
        assertEq(target.const(), 2);
    }

    function testProxyAccessRights() public {
        DummyImpl impl = new DummyImpl(1);
        EIP1967Proxy proxy = new EIP1967Proxy(address(this), address(impl), "");

        impl = new DummyImpl(2);
        vm.prank(user1);
        vm.expectRevert("EIP1967Admin: not an admin");
        proxy.upgradeTo(address(impl));
        vm.prank(user1);
        vm.expectRevert("EIP1967Admin: not an admin");
        proxy.setAdmin(user1);
    }

    function testProxySetAdmin() public {
        DummyImpl impl = new DummyImpl(1);
        EIP1967Proxy proxy = new EIP1967Proxy(address(this), address(impl), "");

        assertEq(proxy.admin(), address(this));
        vm.expectEmit(false, false, false, true);
        emit AdminChanged(address(this), user1);
        proxy.setAdmin(user1);
        assertEq(proxy.admin(), user1);
    }

    function testProxyUpgradeAndCall() public {
        EIP1967Proxy proxy = new EIP1967Proxy(address(this), address(0xdead), "");
        DummyImpl impl = new DummyImpl(1);

        vm.expectEmit(true, false, false, true);
        emit Upgraded(address(impl));
        proxy.upgradeToAndCall(address(impl), abi.encodeWithSelector(DummyImpl.initialize.selector));

        DummyImpl target = DummyImpl(address(proxy));
        assertEq(target.value(), 1);
        assertEq(target.const(), 1);
    }
}
