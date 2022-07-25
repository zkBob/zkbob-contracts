// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "./shared/EIP2470.t.sol";
import "../src/BobToken.sol";
import "../src/proxy/EIP1967Proxy.sol";
import "../src/utils/MultiMinter.sol";

contract BobTokenTest is Test, EIP2470Test {
    EIP1967Proxy proxy;
    BobToken bob;

    address deployer = 0xBF3d6f830CE263CAE987193982192Cd990442B53;
    address user1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address user2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    uint256 pk1 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function setUp() public {
        setUpFactory();
        bytes memory creationCode =
            abi.encodePacked(type(EIP1967Proxy).creationCode, uint256(uint160(deployer)), uint256(uint160(address(0xdead))));
        proxy = EIP1967Proxy(factory.deploy(creationCode, bytes32(uint256(17725258))));
        BobToken impl = new BobToken(address(proxy));
        vm.prank(deployer);
        proxy.upgradeTo(address(impl));
        bob = BobToken(address(proxy));

        assertEq(address(proxy), address(0xB0Bf1847E7CD691A2Dbc619a515FE2FaE8f69B0B));
    }

    function testMetadata() public {
        assertEq(bob.name(), "BOB");
        assertEq(bob.symbol(), "BOB");
        assertEq(bob.decimals(), 18);
    }

    function testMint() public {
        vm.prank(deployer);
        bob.setMinter(user1);

        vm.expectRevert("BOB: not a minter");
        bob.mint(user2, 1 ether);

        vm.prank(user1);
        bob.mint(user2, 1 ether);

        assertEq(bob.totalSupply(), 1 ether);
        assertEq(bob.balanceOf(user2), 1 ether);
    }

    function testMinterChange() public {
        vm.expectRevert();
        bob.setMinter(user1);

        assertEq(bob.minter(), address(0));
        vm.prank(deployer);
        bob.setMinter(user1);
        assertEq(bob.minter(), address(user1));
    }

    function testMultiMinter() public {
        vm.prank(deployer);
        MultiMinter minter = new MultiMinter(address(bob));
        vm.prank(deployer);
        bob.setMinter(address(minter));

        vm.expectRevert("MultiMinter: not an admin");
        minter.setMinter(user1, true);

        vm.prank(deployer);
        minter.setMinter(user1, true);
        vm.prank(deployer);
        minter.setMinter(user2, true);

        assertEq(minter.minter(user1), true);
        assertEq(minter.minter(user2), true);
        assertEq(minter.minter(address(this)), false);

        vm.expectRevert("MultiMinter: not a minter");
        minter.mint(user2, 1 ether);

        vm.prank(user1);
        minter.mint(user2, 1 ether);

        assertEq(bob.totalSupply(), 1 ether);
        assertEq(bob.balanceOf(user2), 1 ether);
    }

    function testPermit() public {
        vm.prank(deployer);
        bob.setMinter(address(this));

        bob.mint(user1, 1 ether);
        uint256 expiry = block.timestamp + 1 days;
        bytes32 digest = ECDSA.toTypedDataHash(
            bob.DOMAIN_SEPARATOR(), keccak256(abi.encode(bob.PERMIT_TYPEHASH(), user1, user2, 1 ether, 0, expiry))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk1, digest);

        vm.expectRevert("BOB: invalid signature");
        bob.permit(user1, user2, 2 ether, expiry, v, r, s);

        vm.warp(expiry + 1 days);
        vm.expectRevert("BOB: expired permit");
        bob.permit(user1, user2, 1 ether, expiry, v, r, s);
        vm.warp(expiry - 1 days);

        assertEq(bob.allowance(user1, user2), 0 ether);
        bob.permit(user1, user2, 1 ether, expiry, v, r, s);
        assertEq(bob.allowance(user1, user2), 1 ether);

        vm.expectRevert("BOB: invalid signature");
        bob.permit(user1, user2, 1 ether, expiry, v, r, s);
    }
}
