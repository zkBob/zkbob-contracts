// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "./shared/Env.t.sol";
import "./shared/EIP2470.t.sol";
import "../src/BobToken.sol";
import "../src/proxy/EIP1967Proxy.sol";
import "./mocks/ERC677Receiver.sol";

contract BobTokenTest is Test, EIP2470Test {
    EIP1967Proxy proxy;
    BobToken bob;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        setUpFactory();
        bytes memory creationCode = bytes.concat(
            vm.getCode("scripts/vanityaddr/contracts/EIP1967Proxy.json"), abi.encode(deployer, mockImpl, "")
        );
        proxy = EIP1967Proxy(factory.deploy(creationCode, bobSalt));
        BobToken impl = new BobToken(address(proxy));
        vm.startPrank(deployer);
        proxy.upgradeTo(address(impl));
        bob = BobToken(address(proxy));

        bob.updateMinter(user1, true, false);
        bob.updateMinter(user2, false, true);
        vm.stopPrank();

        assertEq(address(proxy), bobVanityAddr);

        assertEq(
            bob.DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256("BOB"),
                    keccak256("1"),
                    block.chainid,
                    address(bob)
                )
            )
        );
    }

    function testMetadata() public {
        assertEq(bob.name(), "BOB");
        assertEq(bob.symbol(), "BOB");
        assertEq(bob.decimals(), 18);
    }

    function testMint() public {
        vm.expectRevert("ERC20MintBurn: not a minter");
        bob.mint(user2, 1 ether);

        vm.prank(user2);
        vm.expectRevert("ERC20MintBurn: not a minter");
        bob.mint(user2, 1 ether);

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user2, 1 ether);
        bob.mint(user2, 1 ether);

        assertEq(bob.totalSupply(), 1 ether);
        assertEq(bob.balanceOf(user2), 1 ether);
    }

    function testBurn() public {
        vm.startPrank(user1);
        bob.mint(user1, 1 ether);
        bob.mint(user2, 1 ether);
        vm.stopPrank();

        vm.expectRevert("ERC20MintBurn: not a burner");
        bob.burn(1 ether);

        vm.prank(user1);
        vm.expectRevert("ERC20MintBurn: not a burner");
        bob.burn(1 ether);

        vm.prank(user2);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user2, address(0), 1 ether);
        bob.burn(1 ether);

        assertEq(bob.totalSupply(), 1 ether);
        assertEq(bob.balanceOf(user1), 1 ether);
        assertEq(bob.balanceOf(user2), 0 ether);
    }

    function testMinterChange() public {
        vm.expectRevert("Ownable: caller is not the owner");
        bob.updateMinter(user3, true, true);

        assertEq(bob.isMinter(user1), true);
        assertEq(bob.isMinter(user2), false);
        assertEq(bob.isMinter(user3), false);
        assertEq(bob.isBurner(user1), false);
        assertEq(bob.isBurner(user2), true);
        assertEq(bob.isBurner(user3), false);
        vm.startPrank(deployer);
        bob.updateMinter(user1, false, false);
        bob.updateMinter(user2, false, false);
        bob.updateMinter(user3, true, true);
        vm.stopPrank();
        assertEq(bob.isMinter(user1), false);
        assertEq(bob.isMinter(user2), false);
        assertEq(bob.isMinter(user3), true);
        assertEq(bob.isBurner(user1), false);
        assertEq(bob.isBurner(user2), false);
        assertEq(bob.isBurner(user3), true);
    }

    function testPermit() public {
        vm.prank(user1);
        bob.mint(user1, 1 ether);

        uint256 expiry = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(pk1, user1, user2, 1 ether, 0, expiry);

        // different message
        vm.expectRevert("ERC20Permit: invalid ERC2612 signature");
        bob.permit(user1, user2, 2 ether, expiry, v, r, s);

        // expired message
        vm.warp(expiry + 1 days);
        vm.expectRevert("ERC20Permit: expired permit");
        bob.permit(user1, user2, 1 ether, expiry, v, r, s);
        vm.warp(expiry - 1 days);

        // correct permit with nonce 0
        assertEq(bob.allowance(user1, user2), 0 ether);
        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, 1 ether);
        bob.permit(user1, user2, 1 ether, expiry, v, r, s);
        assertEq(bob.allowance(user1, user2), 1 ether);

        // expired nonce
        vm.expectRevert("ERC20Permit: invalid ERC2612 signature");
        bob.permit(user1, user2, 1 ether, expiry, v, r, s);
    }

    function testPermitFailsAfterHardFork() public {
        vm.prank(user1);
        bob.mint(user1, 1 ether);

        uint256 expiry = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(pk1, user1, user2, 1 ether, 0, expiry);

        bytes32 sep = bob.DOMAIN_SEPARATOR();

        vm.chainId(1234);
        assertTrue(sep != bob.DOMAIN_SEPARATOR());
        vm.expectRevert("ERC20Permit: invalid ERC2612 signature");
        bob.permit(user1, user2, 1 ether, expiry, v, r, s);

        vm.chainId(31337);
        assertTrue(sep == bob.DOMAIN_SEPARATOR());
        bob.permit(user1, user2, 1 ether, expiry, v, r, s);
        assertEq(bob.allowance(user1, user2), 1 ether);
    }

    function testReceiveWithPermit() public {
        vm.prank(user1);
        bob.mint(user1, 1 ether);

        uint256 expiry = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(pk1, user1, user2, 1 ether, 0, expiry);

        vm.prank(user1);
        bob.approve(user2, 0.1 ether);

        vm.expectRevert("ERC20Permit: invalid ERC2612 signature");
        bob.receiveWithPermit(user1, 1 ether, expiry, v, r, s);
        vm.prank(user2);
        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, 1 ether);
        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, 0);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, 1 ether);
        bob.receiveWithPermit(user1, 1 ether, expiry, v, r, s);
        assertEq(bob.balanceOf(user1), 0 ether);
        assertEq(bob.balanceOf(user2), 1 ether);
        assertEq(bob.allowance(user1, user2), 0 ether);
    }

    function testReceiveWithSaltedPermit() public {
        vm.prank(user1);
        bob.mint(user1, 1 ether);

        uint256 expiry = block.timestamp + 1 days;
        bytes32 salt = bytes32(uint256(123));
        (uint8 v, bytes32 r, bytes32 s) = _signSaltedPermit(pk1, user1, user2, 1 ether, 0, expiry, salt);

        vm.prank(user1);
        bob.approve(user2, 0.1 ether);

        vm.expectRevert("ERC20Permit: invalid signature");
        bob.receiveWithSaltedPermit(user1, 1 ether, expiry, salt, v, r, s);
        vm.prank(user2);
        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, 1 ether);
        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, 0);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, 1 ether);
        bob.receiveWithSaltedPermit(user1, 1 ether, expiry, salt, v, r, s);
        assertEq(bob.balanceOf(user1), 0 ether);
        assertEq(bob.balanceOf(user2), 1 ether);
        assertEq(bob.allowance(user1, user2), 0 ether);
    }

    function _signPermit(
        uint256 _pk,
        address _holder,
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 _expiry
    )
        internal
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 digest = ECDSA.toTypedDataHash(
            bob.DOMAIN_SEPARATOR(),
            keccak256(abi.encode(bob.PERMIT_TYPEHASH(), _holder, _spender, _value, _nonce, _expiry))
        );
        return vm.sign(_pk, digest);
    }

    function _signSaltedPermit(
        uint256 _pk,
        address _holder,
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 _expiry,
        bytes32 _salt
    )
        internal
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 digest = ECDSA.toTypedDataHash(
            bob.DOMAIN_SEPARATOR(),
            keccak256(abi.encode(bob.SALTED_PERMIT_TYPEHASH(), _holder, _spender, _value, _nonce, _expiry, _salt))
        );
        return vm.sign(_pk, digest);
    }

    function testBlocklist() public {
        vm.prank(user1);
        bob.mint(user1, 1 ether);

        address erc677Receiver = address(new ERC677Receiver());

        vm.prank(user1);
        bob.approve(user2, 1 ether);
        vm.prank(user2);
        bob.approve(user1, 1 ether);
        vm.prank(user1);
        bob.transfer(user2, 0.1 ether);
        vm.prank(user1);
        bob.transferAndCall(erc677Receiver, 0.1 ether, "");
        vm.prank(user2);
        bob.transferFrom(user1, user2, 0.1 ether);
        vm.prank(user1);
        bob.transferFrom(user2, user1, 0.1 ether);

        vm.expectRevert("Blocklist: caller is not the blocklister");
        bob.blockAccount(user1);

        vm.prank(deployer);
        bob.updateBlocklister(address(this));

        assertEq(bob.isBlocked(user1), false);
        bob.blockAccount(user1);
        assertEq(bob.isBlocked(user1), true);

        // new approvals still work
        vm.prank(user1);
        bob.approve(user2, 1 ether);

        // cannot transfer
        vm.prank(user1);
        vm.expectRevert("ERC20: account frozen");
        bob.transfer(user2, 0.1 ether);

        // cannot transfer and call
        vm.prank(user1);
        vm.expectRevert("ERC20: account frozen");
        bob.transferAndCall(erc677Receiver, 0.1 ether, "");

        // cannot receiver transfer
        vm.prank(user2);
        vm.expectRevert("ERC20: account frozen");
        bob.transfer(user1, 0.1 ether);

        // cannot use existing approvals
        vm.prank(user2);
        vm.expectRevert("ERC20: account frozen");
        bob.transferFrom(user1, address(this), 0.1 ether);

        // cannot spend third-party approvals
        // vm.prank(user1);
        // vm.expectRevert("ERC20: account frozen");
        // bob.transferFrom(user2, address(this), 0.1 ether);

        assertEq(bob.isBlocked(user1), true);
        bob.unblockAccount(user1);
        assertEq(bob.isBlocked(user1), false);
    }

    function testClaimTokens() public {
        ERC20PresetMinterPauser token = new ERC20PresetMinterPauser("Test", "TEST");
        token.mint(address(bob), 1 ether);
        vm.deal(address(bob), 1 ether);
        vm.deal(address(user1), 0 ether);

        vm.prank(deployer);
        bob.setClaimingAdmin(user1);

        vm.expectRevert("Claimable: not authorized for claiming");
        bob.claimTokens(address(0), user1);
        vm.expectRevert("Claimable: not authorized for claiming");
        bob.claimTokens(address(token), user1);

        // test with proxy admin
        vm.startPrank(deployer);
        bob.claimTokens(address(0), user1);
        bob.claimTokens(address(token), user1);
        vm.stopPrank();

        assertEq(token.balanceOf(address(bob)), 0 ether);
        assertEq(token.balanceOf(user1), 1 ether);
        assertEq(address(bob).balance, 0 ether);
        assertEq(user1.balance, 1 ether);

        // test with claiming admin
        token.mint(address(bob), 1 ether);
        vm.deal(address(bob), 1 ether);
        vm.deal(address(user1), 0 ether);

        vm.startPrank(user1);
        bob.claimTokens(address(0), user1);
        bob.claimTokens(address(token), user1);
        vm.stopPrank();

        assertEq(token.balanceOf(address(bob)), 0 ether);
        assertEq(token.balanceOf(user1), 2 ether);
        assertEq(address(bob).balance, 0 ether);
        assertEq(user1.balance, 1 ether);
    }

    function testRecoverySettings() public {
        vm.expectRevert("Ownable: caller is not the owner");
        bob.setRecoveryAdmin(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        bob.setRecoveredFundsReceiver(user2);
        vm.expectRevert("Ownable: caller is not the owner");
        bob.setRecoveryLimitPercent(0.1 ether);
        vm.expectRevert("Ownable: caller is not the owner");
        bob.setRecoveryRequestTimelockPeriod(1 days);

        _setUpRecoveryConfig();

        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        bob.setRecoveryAdmin(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        bob.setRecoveredFundsReceiver(user2);
        vm.expectRevert("Ownable: caller is not the owner");
        bob.setRecoveryLimitPercent(0.1 ether);
        vm.expectRevert("Ownable: caller is not the owner");
        bob.setRecoveryRequestTimelockPeriod(1 days);
        vm.stopPrank();

        assertEq(bob.recoveryAdmin(), user1);
        assertEq(bob.recoveredFundsReceiver(), user2);
        assertEq(bob.recoveryLimitPercent(), 0.1 ether);
        assertEq(bob.recoveryRequestTimelockPeriod(), 1 days);
    }

    function testRecoverySuccessPath() public {
        _setUpRecoveryConfig();

        vm.startPrank(user1);

        address[] memory accounts = new address[](2);
        uint256[] memory values = new uint256[](2);
        accounts[0] = address(0xdead);
        values[0] = 2 ether;
        accounts[1] = address(0xbeaf);
        values[1] = 2 ether;
        bob.requestRecovery(accounts, values);
        values[1] = 1 ether;

        vm.warp(block.timestamp + 1 days);

        assertEq(bob.totalRecovered(), 0 ether);
        assertEq(bob.balanceOf(address(0xdead)), 100 ether);
        assertEq(bob.balanceOf(address(0xbeaf)), 1 ether);
        assertEq(bob.balanceOf(user2), 0 ether);

        bob.executeRecovery(accounts, values);

        assertEq(bob.totalRecovered(), 3 ether);
        assertEq(bob.balanceOf(address(0xdead)), 98 ether);
        assertEq(bob.balanceOf(address(0xbeaf)), 0 ether);
        assertEq(bob.balanceOf(user2), 3 ether);
    }

    function testCancelRecoveryRequest() public {
        _setUpRecoveryConfig();

        vm.startPrank(user1);

        address[] memory accounts = new address[](2);
        uint256[] memory values = new uint256[](2);
        accounts[0] = address(0xdead);
        values[0] = 2 ether;
        accounts[1] = address(0xbeaf);
        values[1] = 2 ether;

        assert(bob.recoveryRequestHash() == bytes32(0));
        bob.requestRecovery(accounts, values);
        assert(bob.recoveryRequestHash() != bytes32(0));
        bob.cancelRecovery();
        assert(bob.recoveryRequestHash() == bytes32(0));
    }

    function testIsRecoveryEnabled() public {
        assertEq(bob.isRecoveryEnabled(), false);
        _setUpRecoveryConfig();
        assertEq(bob.isRecoveryEnabled(), true);
    }

    function testRecoveryLimit() public {
        _setUpRecoveryConfig();

        vm.startPrank(user1);

        address[] memory accounts = new address[](2);
        uint256[] memory values = new uint256[](2);
        accounts[0] = address(0xdead);
        values[0] = 2 ether;
        accounts[1] = address(0xbeaf);
        values[1] = 2 ether;
        bob.requestRecovery(accounts, values);
        values[1] = 1 ether;

        vm.warp(block.timestamp + 1 days);

        vm.stopPrank();
        vm.prank(deployer);
        bob.setRecoveryLimitPercent(0.01 ether);
        vm.prank(user1);
        vm.expectRevert("Recovery: exceed recovery limit");
        bob.executeRecovery(accounts, values);
        vm.prank(deployer);
        bob.setRecoveryLimitPercent(0.1 ether);
        vm.prank(user1);
        bob.executeRecovery(accounts, values);

        assertEq(bob.totalRecovered(), 3 ether);
    }

    function testRecoveryTimelock() public {
        _setUpRecoveryConfig();

        vm.startPrank(user1);

        address[] memory accounts = new address[](2);
        uint256[] memory values = new uint256[](2);
        accounts[0] = address(0xdead);
        values[0] = 2 ether;
        accounts[1] = address(0xbeaf);
        values[1] = 2 ether;
        bob.requestRecovery(accounts, values);
        values[1] = 1 ether;

        vm.warp(block.timestamp + 0.5 days);

        vm.expectRevert("Recovery: request still timelocked");
        bob.executeRecovery(accounts, values);

        vm.warp(block.timestamp + 0.5 days);

        bob.executeRecovery(accounts, values);

        assertEq(bob.totalRecovered(), 3 ether);
    }

    function testRecoveryEscape() public {
        _setUpRecoveryConfig();

        vm.startPrank(user1);

        address[] memory accounts = new address[](2);
        uint256[] memory values = new uint256[](2);
        accounts[0] = address(0xdead);
        values[0] = 2 ether;
        accounts[1] = address(0xbeaf);
        values[1] = 2 ether;
        bob.requestRecovery(accounts, values);
        values[1] = 1 ether;

        vm.warp(block.timestamp + 1 days);

        vm.stopPrank();
        vm.prank(address(0xdead));
        bob.transfer(address(0xdeaddead), 100 ether);
        vm.prank(address(0xbeaf));
        bob.transfer(address(0xbeafbeaf), 0.5 ether);
        vm.startPrank(user1);

        bob.executeRecovery(accounts, values);

        assertEq(bob.totalRecovered(), 0.5 ether);
        assertEq(bob.balanceOf(address(0xdead)), 0 ether);
        assertEq(bob.balanceOf(address(0xdeaddead)), 100 ether);
        assertEq(bob.balanceOf(address(0xbeaf)), 0 ether);
        assertEq(bob.balanceOf(address(0xbeafbeaf)), 0.5 ether);
        assertEq(bob.balanceOf(user2), 0.5 ether);
    }

    function testRecoveryFromBlockedAddress() public {
        _setUpRecoveryConfig();

        vm.startPrank(deployer);
        bob.updateBlocklister(deployer);
        bob.blockAccount(address(0xdead));
        vm.stopPrank();

        vm.startPrank(user1);

        address[] memory accounts = new address[](2);
        uint256[] memory values = new uint256[](2);
        accounts[0] = address(0xdead);
        values[0] = 2 ether;
        accounts[1] = address(0xbeaf);
        values[1] = 2 ether;
        bob.requestRecovery(accounts, values);
        values[1] = 1 ether;

        vm.warp(block.timestamp + 1 days);

        assertEq(bob.totalRecovered(), 0 ether);
        assertEq(bob.balanceOf(address(0xdead)), 100 ether);
        assertEq(bob.balanceOf(address(0xbeaf)), 1 ether);
        assertEq(bob.balanceOf(user2), 0 ether);

        bob.executeRecovery(accounts, values);

        assertEq(bob.totalRecovered(), 3 ether);
        assertEq(bob.balanceOf(address(0xdead)), 98 ether);
        assertEq(bob.balanceOf(address(0xbeaf)), 0 ether);
        assertEq(bob.balanceOf(user2), 3 ether);
    }

    function _setUpRecoveryConfig() internal {
        vm.startPrank(deployer);
        bob.updateMinter(deployer, true, true);
        bob.setRecoveryAdmin(user1);
        bob.setRecoveredFundsReceiver(user2);
        bob.setRecoveryLimitPercent(0.1 ether);
        bob.setRecoveryRequestTimelockPeriod(1 days);
        bob.mint(address(0xdead), 100 ether);
        bob.mint(address(0xbeaf), 1 ether);
        vm.stopPrank();
    }

    function testAccessRights() public {
        vm.startPrank(user3);
        vm.expectRevert("EIP1967Admin: not an admin");
        proxy.upgradeTo(address(0xdead));
        vm.expectRevert("Ownable: caller is not the owner");
        bob.transferOwnership(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        bob.updateMinter(user1, true, true);
        vm.expectRevert("Ownable: caller is not the owner");
        bob.setClaimingAdmin(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        bob.setRecoveryAdmin(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        bob.setRecoveredFundsReceiver(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        bob.setRecoveryLimitPercent(0.1 ether);
        vm.expectRevert("Ownable: caller is not the owner");
        bob.setRecoveryRequestTimelockPeriod(3 days);
        vm.expectRevert("Ownable: caller is not the owner");
        bob.updateBlocklister(user1);
        vm.expectRevert("Blocklist: caller is not the blocklister");
        bob.blockAccount(user1);
        vm.expectRevert("Blocklist: caller is not the blocklister");
        bob.unblockAccount(user1);
        vm.expectRevert("ERC20MintBurn: not a minter");
        bob.mint(user1, 1 ether);
        vm.expectRevert("ERC20MintBurn: not a burner");
        bob.burn(1 ether);
        vm.expectRevert("Claimable: not authorized for claiming");
        bob.claimTokens(address(0), user1);
        vm.expectRevert("Recovery: not authorized for recovery");
        bob.requestRecovery(new address[](1), new uint256[](1));
        vm.expectRevert("Recovery: not authorized for recovery");
        bob.executeRecovery(new address[](1), new uint256[](1));
        vm.expectRevert("Recovery: not authorized for recovery");
        bob.cancelRecovery();
        vm.stopPrank();

        vm.startPrank(deployer);
        proxy.upgradeTo(address(new BobToken(address(bob))));
        bob.transferOwnership(user1);
        bob.updateMinter(user1, true, true);
        bob.setClaimingAdmin(user1);
        bob.setRecoveryAdmin(user1);
        bob.setRecoveredFundsReceiver(user1);
        bob.setRecoveryLimitPercent(0.1 ether);
        bob.setRecoveryRequestTimelockPeriod(3 days);
        bob.updateBlocklister(user1);
        vm.expectRevert("Blocklist: caller is not the blocklister");
        bob.blockAccount(user1);
        vm.expectRevert("Blocklist: caller is not the blocklister");
        bob.unblockAccount(user1);
        vm.expectRevert("ERC20MintBurn: not a minter");
        bob.mint(user1, 1 ether);
        vm.expectRevert("ERC20MintBurn: not a burner");
        bob.burn(1 ether);
        bob.claimTokens(address(0), user1);
        vm.expectRevert("Recovery: not enabled");
        bob.requestRecovery(new address[](1), new uint256[](1));
        vm.expectRevert("Recovery: no active recovery request");
        bob.executeRecovery(new address[](1), new uint256[](1));
        vm.expectRevert("Recovery: no active recovery request");
        bob.cancelRecovery();
        vm.stopPrank();

        vm.startPrank(user1);
        bob.blockAccount(user2);
        bob.unblockAccount(user2);
        bob.mint(user1, 1 ether);
        bob.burn(1 ether);
        vm.stopPrank();
    }
}
