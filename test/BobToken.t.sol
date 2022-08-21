// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "./shared/EIP2470.t.sol";
import "../src/BobToken.sol";
import "../src/proxy/EIP1967Proxy.sol";
import "../src/MultiMinter.sol";
import "./mocks/ERC677Receiver.sol";

contract BobTokenTest is Test, EIP2470Test {
    EIP1967Proxy proxy;
    BobToken bob;

    address deployer = 0xBF3d6f830CE263CAE987193982192Cd990442B53;
    address user1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address user2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    uint256 pk1 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    address vanityAddr = address(0xB0B65813DD450B7c98Fed97404fAbAe179A00B0B);
    address mockImpl = address(0xdead);
    bytes32 salt = bytes32(uint256(298396503));

    function setUp() public {
        setUpFactory();
        bytes memory creationCode =
            abi.encodePacked(type(EIP1967Proxy).creationCode, uint256(uint160(deployer)), uint256(uint160(mockImpl)));
        proxy = EIP1967Proxy(factory.deploy(creationCode, salt));
        BobToken impl = new BobToken(address(proxy));
        vm.prank(deployer);
        proxy.upgradeTo(address(impl));
        bob = BobToken(address(proxy));

        assertEq(address(proxy), vanityAddr);

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
        vm.prank(deployer);
        bob.setMinter(user1);

        vm.expectRevert("MintableERC20: not a minter");
        bob.mint(user2, 1 ether);

        vm.prank(user1);
        bob.mint(user2, 1 ether);

        assertEq(bob.totalSupply(), 1 ether);
        assertEq(bob.balanceOf(user2), 1 ether);
    }

    function testMinterChange() public {
        vm.expectRevert("Ownable: caller is not the owner");
        bob.setMinter(user1);

        assertEq(bob.minter(), address(0));
        vm.prank(deployer);
        bob.setMinter(user1);
        assertEq(bob.minter(), address(user1));
        vm.prank(deployer);
        bob.setMinter(user2);
        assertEq(bob.minter(), address(user2));
    }

    function testMultiMinter() public {
        vm.prank(deployer);
        MultiMinter minter = new MultiMinter(address(bob));
        vm.prank(deployer);
        bob.setMinter(address(minter));

        vm.expectRevert("Ownable: caller is not the owner");
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
        bob.permit(user1, user2, 1 ether, expiry, v, r, s);
        assertEq(bob.allowance(user1, user2), 1 ether);

        // expired nonce
        vm.expectRevert("ERC20Permit: invalid ERC2612 signature");
        bob.permit(user1, user2, 1 ether, expiry, v, r, s);
    }

    function testReceiveWithPermit() public {
        vm.prank(deployer);
        bob.setMinter(address(this));

        bob.mint(user1, 1 ether);

        uint256 expiry = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(pk1, user1, user2, 1 ether, 0, expiry);

        vm.expectRevert("ERC20Permit: invalid ERC2612 signature");
        bob.receiveWithPermit(user1, 1 ether, expiry, v, r, s);
        vm.prank(user2);
        bob.receiveWithPermit(user1, 1 ether, expiry, v, r, s);
        assertEq(bob.balanceOf(user1), 0 ether);
        assertEq(bob.balanceOf(user2), 1 ether);
    }

    function testSaltedPermit() public {
        vm.prank(deployer);
        bob.setMinter(address(this));

        bob.mint(user1, 1 ether);

        uint256 expiry = block.timestamp + 1 days;
        bytes32 salt = bytes32(uint256(123));
        (uint8 v, bytes32 r, bytes32 s) = _signSaltedPermit(pk1, user1, user2, 1 ether, 0, expiry, salt);

        // different message
        vm.expectRevert("ERC20Permit: invalid signature");
        bob.saltedPermit(user1, user2, 2 ether, expiry, salt, v, r, s);

        // expired message
        vm.warp(expiry + 1 days);
        vm.expectRevert("ERC20Permit: expired permit");
        bob.saltedPermit(user1, user2, 1 ether, expiry, salt, v, r, s);
        vm.warp(expiry - 1 days);

        // correct permit with nonce 0
        assertEq(bob.allowance(user1, user2), 0 ether);
        bob.saltedPermit(user1, user2, 1 ether, expiry, salt, v, r, s);
        assertEq(bob.allowance(user1, user2), 1 ether);

        // expired nonce
        vm.expectRevert("ERC20Permit: invalid signature");
        bob.saltedPermit(user1, user2, 1 ether, expiry, salt, v, r, s);
    }

    function testReceiveWithSaltedPermit() public {
        vm.prank(deployer);
        bob.setMinter(address(this));

        bob.mint(user1, 1 ether);

        uint256 expiry = block.timestamp + 1 days;
        bytes32 salt = bytes32(uint256(123));
        (uint8 v, bytes32 r, bytes32 s) = _signSaltedPermit(pk1, user1, user2, 1 ether, 0, expiry, salt);

        vm.expectRevert("ERC20Permit: invalid signature");
        bob.receiveWithSaltedPermit(user1, 1 ether, expiry, salt, v, r, s);
        vm.prank(user2);
        bob.receiveWithSaltedPermit(user1, 1 ether, expiry, salt, v, r, s);
        assertEq(bob.balanceOf(user1), 0 ether);
        assertEq(bob.balanceOf(user2), 1 ether);
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
        vm.prank(deployer);
        bob.setMinter(address(this));
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
        bob.setMinter(deployer);
        bob.setRecoveryAdmin(user1);
        bob.setRecoveredFundsReceiver(user2);
        bob.setRecoveryLimitPercent(0.1 ether);
        bob.setRecoveryRequestTimelockPeriod(1 days);
        bob.mint(address(0xdead), 100 ether);
        bob.mint(address(0xbeaf), 1 ether);
        vm.stopPrank();
    }
}
