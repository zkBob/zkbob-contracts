// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "../shared/Env.t.sol";
import "../mocks/TransferVerifierMock.sol";
import "../mocks/TreeUpdateVerifierMock.sol";
import "../mocks/BatchDepositVerifierMock.sol";
import "../mocks/DummyImpl.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPool.sol";
import "../../src/BobToken.sol";
import "../../src/zkbob/manager/MutableOperatorManager.sol";
import "../../src/utils/UniswapV3Seller.sol";
import "../shared/ForkTests.t.sol";

contract ZkBobPoolTest is AbstractMainnetForkTest {
    uint256 private constant initialRoot = 11469701942666298368112882412133877458305516134926649826543144744382391691533;

    address constant uniV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant uniV3Quoter = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    address constant uniV3Positions = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    bytes constant zkAddress = "QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mriHfN";

    ZkBobPool pool;
    BobToken bob;
    IOperatorManager operatorManager;

    event Message(uint256 indexed index, bytes32 indexed hash, bytes message);

    event SubmitDirectDeposit(
        address indexed sender,
        uint256 indexed nonce,
        address fallbackUser,
        ZkAddress.ZkAddress zkAddress,
        uint64 deposit
    );
    event RefundDirectDeposit(uint256 indexed nonce, address receiver, uint256 amount);
    event CompleteDirectDepositBatch(uint256 indexed treeIndex, uint256[] indices);

    function setUp() public {
        EIP1967Proxy bobProxy = new EIP1967Proxy(address(this), mockImpl, "");
        BobToken bobImpl = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(bobImpl));
        bob = BobToken(address(bobProxy));
        bob.updateMinter(address(this), true, true);

        ZkBobPool impl =
        new ZkBobPool(0, address(bob), new TransferVerifierMock(), new TreeUpdateVerifierMock(), new BatchDepositVerifierMock());
        EIP1967Proxy poolProxy = new EIP1967Proxy(address(this), address(impl), abi.encodeWithSelector(
            ZkBobPool.initialize.selector, initialRoot,
            1_000_000 ether, 100_000 ether, 100_000 ether, 10_000 ether, 10_000 ether, 0, 0
        ));
        pool = ZkBobPool(address(poolProxy));

        operatorManager = new MutableOperatorManager(user2, user3, "https://example.com");
        pool.setOperatorManager(operatorManager);
        pool.setDirectDepositFee(0.1 gwei);
        pool.setDirectDepositTimeout(1 days);

        bob.mint(address(user1), 1 ether);
    }

    function testSimpleTransaction() public {
        bytes memory data1 = _encodePermitDeposit(0.5 ether, 0.01 ether);
        _transact(data1);

        bytes memory data2 = _encodeTransfer();
        _transact(data2);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(bob.balanceOf(user3), 0.02 ether);
    }

    function testGetters() public {
        assertEq(pool.pool_index(), 0);
        assertEq(pool.denominator(), 1 gwei);

        bytes memory data1 = _encodePermitDeposit(0.5 ether, 0.01 ether);
        _transact(data1);

        assertEq(pool.pool_index(), 128);

        bytes memory data2 = _encodeTransfer();
        _transact(data2);

        assertEq(pool.pool_index(), 256);
    }

    function testAuthRights() public {
        vm.startPrank(user1);

        vm.expectRevert("ZkBobPool: not initializer");
        pool.initialize(0, 0, 0, 0, 0, 0, 0, 0);
        vm.expectRevert("Ownable: caller is not the owner");
        pool.setOperatorManager(IOperatorManager(address(0)));
        vm.expectRevert("Ownable: caller is not the owner");
        pool.setTokenSeller(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        pool.setLimits(0, 0, 0, 0, 0, 0, 0, 0);
        vm.expectRevert("Ownable: caller is not the owner");
        pool.setUsersTier(0, new address[](1));
        vm.expectRevert("Ownable: caller is not the owner");
        pool.resetDailyLimits(0);

        vm.stopPrank();
    }

    function testUsersTiers() public {
        pool.setLimits(1, 2_000_000 ether, 200_000 ether, 200_000 ether, 20_000 ether, 20_000 ether, 0, 0);
        address[] memory users = new address[](1);
        users[0] = user2;
        pool.setUsersTier(1, users);

        assertEq(pool.getLimitsFor(user1).tier, 0);
        assertEq(pool.getLimitsFor(user1).depositCap, 10_000 gwei);
        assertEq(pool.getLimitsFor(user2).tier, 1);
        assertEq(pool.getLimitsFor(user2).depositCap, 20_000 gwei);
    }

    function testResetDailyLimits() public {
        bob.mint(address(user1), 10 ether);

        bytes memory data1 = _encodePermitDeposit(5 ether, 0.01 ether);
        _transact(data1);

        bytes memory data2 = _encodeWithdrawal(user1, 4 ether, 0 ether);
        _transact(data2);

        assertEq(pool.getLimitsFor(user1).dailyDepositCapUsage, 5 gwei);
        assertEq(pool.getLimitsFor(user1).dailyWithdrawalCapUsage, 4.01 gwei);

        pool.resetDailyLimits(0);

        assertEq(pool.getLimitsFor(user1).dailyDepositCapUsage, 0);
        assertEq(pool.getLimitsFor(user1).dailyWithdrawalCapUsage, 0);
    }

    function testSetOperatorManager() public {
        assertEq(address(pool.operatorManager()), address(operatorManager));

        IOperatorManager newOperatorManager = new MutableOperatorManager(user2, user3, "https://example.com");
        pool.setOperatorManager(newOperatorManager);

        assertEq(address(pool.operatorManager()), address(newOperatorManager));
    }

    function testPermitDeposit() public {
        bytes memory data = _encodePermitDeposit(0.5 ether, 0.01 ether);
        _transact(data);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(bob.balanceOf(user1), 0.49 ether);
        assertEq(bob.balanceOf(address(pool)), 0.5 ether);
        assertEq(bob.balanceOf(user3), 0.01 ether);
    }

    function testUsualDeposit() public {
        vm.prank(user1);
        bob.approve(address(pool), 0.51 ether);

        bytes memory data = _encodeDeposit(0.5 ether, 0.01 ether);
        _transact(data);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(bob.balanceOf(user1), 0.49 ether);
        assertEq(bob.balanceOf(address(pool)), 0.5 ether);
        assertEq(bob.balanceOf(user3), 0.01 ether);
    }

    function testWithdrawal() public {
        bytes memory data1 = _encodePermitDeposit(0.5 ether, 0.01 ether);
        _transact(data1);

        bytes memory data2 = _encodeWithdrawal(user1, 0.1 ether, 0 ether);
        _transact(data2);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(bob.balanceOf(user1), 0.59 ether);
        assertEq(bob.balanceOf(address(pool)), 0.39 ether);
        assertEq(bob.balanceOf(user3), 0.02 ether);
    }

    function _setupNativeSwaps() internal {
        vm.makePersistent(address(pool), address(bob));
        vm.makePersistent(
            EIP1967Proxy(payable(address(pool))).implementation(), EIP1967Proxy(payable(address(bob))).implementation()
        );
        vm.makePersistent(
            address(pool.operatorManager()), address(pool.transfer_verifier()), address(pool.tree_verifier())
        );

        // fork mainnet
        vm.createSelectFork(forkRpcUrl, forkBlock);

        // create BOB-USDC 0.05% pool at Uniswap V3
        deal(usdc, address(this), 1e9);
        IERC20(usdc).approve(uniV3Positions, 1e9);
        address token0 = usdc;
        address token1 = address(bob);
        int24 tickLower = 276320;
        int24 tickUpper = 276330;
        uint256 amount0Desired = 1e9;
        uint256 amount1Desired = 0;
        uint160 price = TickMath.getSqrtRatioAtTick(tickLower);
        if (token1 < token0) {
            (token0, token1) = (token1, token0);
            (tickLower, tickUpper) = (-tickUpper, -tickLower);
            (amount0Desired, amount1Desired) = (amount1Desired, amount0Desired);
            price = TickMath.getSqrtRatioAtTick(tickUpper);
        }
        INonfungiblePositionManager(uniV3Positions).createAndInitializePoolIfNecessary(token0, token1, 500, price);
        INonfungiblePositionManager(uniV3Positions).mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: 500,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );

        // enable token swaps for ETH
        pool.setTokenSeller(address(new UniswapV3Seller(uniV3Router, uniV3Quoter, address(bob), 500, usdc, 500)));
    }

    function testNativeWithdrawal() public {
        _setupNativeSwaps();

        vm.deal(user1, 0);

        bytes memory data1 = _encodePermitDeposit(0.99 ether, 0.01 ether);
        _transact(data1);

        // user1 withdraws 0.4 BOB, 0.3 BOB gets converted to ETH
        uint256 quote2 = pool.tokenSeller().quoteSellForETH(0.3 ether);
        bytes memory data2 = _encodeWithdrawal(user1, 0.4 ether, 0.3 ether);
        _transact(data2);

        address dummy = address(new DummyImpl(0));
        uint256 quote3 = pool.tokenSeller().quoteSellForETH(0.3 ether);
        bytes memory data3 = _encodeWithdrawal(dummy, 0.4 ether, 0.3 ether);
        _transact(data3);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(bob.balanceOf(user1), 0.1 ether);
        assertEq(bob.balanceOf(dummy), 0.1 ether);
        assertEq(bob.balanceOf(address(pool)), 0.17 ether);
        assertEq(bob.balanceOf(user3), 0.03 ether);
        assertGt(user1.balance, 1 gwei);
        assertEq(user1.balance, quote2);
        assertGt(dummy.balance, 1 gwei);
        assertEq(dummy.balance, quote3);
    }

    function testNativeWithdrawalOutOfLiquidity() public {
        _setupNativeSwaps();

        bob.mint(address(user1), 9999.01 ether);

        vm.deal(user1, 0);

        bytes memory data1 = _encodePermitDeposit(10000 ether, 0.01 ether);
        _transact(data1);

        uint256 quote2 = pool.tokenSeller().quoteSellForETH(60 ether);
        bytes memory data2 = _encodeWithdrawal(user1, 100 ether, 60 ether);
        _transact(data2);

        assertEq(bob.balanceOf(user1), 40 ether);
        assertEq(bob.balanceOf(address(pool)), 9900.01 ether);
        assertGt(user1.balance, 1 gwei);

        uint256 quote31 = pool.tokenSeller().quoteSellForETH(1000 ether);
        uint256 quote32 = pool.tokenSeller().quoteSellForETH(3000 ether);
        bytes memory data3 = _encodeWithdrawal(user1, 5000 ether, 3000 ether);
        _transact(data3);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(bob.balanceOf(user3), 0.03 ether);
        assertGt(bob.balanceOf(user1), 40 ether + 2000 ether + 2000 ether);
        assertEq(bob.balanceOf(address(pool)), 4899.98 ether);
        assertGt(user1.balance, 1 gwei);
        assertEq(quote31, quote32);
        assertEq(user1.balance, quote2 + quote31);
    }

    function testRejectNegativeDeposits() public {
        bytes memory data1 = _encodePermitDeposit(0.99 ether, 0.01 ether);
        _transact(data1);

        bytes memory data2 = _encodePermitDeposit(-0.5 ether, 1 ether);
        _transactReverted(data2, "ZkBobPool: incorrect deposit amounts");

        vm.prank(user1);
        bob.approve(address(pool), 0.5 ether);

        bytes memory data3 = _encodeDeposit(-0.5 ether, 1 ether);
        _transactReverted(data3, "ZkBobPool: incorrect deposit amounts");
    }

    function _setUpDD() internal {
        deal(address(bob), user1, 100 ether);
        deal(address(bob), user2, 100 ether);

        pool.setLimits(1, 2_000_000 ether, 200_000 ether, 200_000 ether, 20_000 ether, 20_000 ether, 25 ether, 10 ether);
        address[] memory users = new address[](1);
        users[0] = user1;
        pool.setUsersTier(1, users);

        pool.setDirectDepositFee(0.1 gwei);
    }

    function testDirectDepositSubmit() public {
        _setUpDD();

        vm.prank(user2);
        vm.expectRevert("ZkBobAccounting: single direct deposit cap exceeded");
        bob.transferAndCall(address(pool), 10 ether, abi.encode(user2, zkAddress));

        vm.prank(user1);
        vm.expectRevert("ZkBobPool: direct deposit amount is too low");
        bob.transferAndCall(address(pool), 0.01 ether, abi.encode(user2, zkAddress));

        vm.prank(user1);
        vm.expectRevert(ZkAddress.InvalidZkAddressLength.selector);
        bob.transferAndCall(address(pool), 10 ether, abi.encode(user2, "invalid"));

        vm.prank(user1);
        vm.expectRevert("ZkBobAccounting: single direct deposit cap exceeded");
        bob.transferAndCall(address(pool), 15 ether, abi.encode(user2, zkAddress));

        vm.expectEmit(true, true, false, true);
        emit SubmitDirectDeposit(user1, 0, user2, ZkAddress.parseZkAddress(zkAddress, 0), 9.9 gwei);
        vm.prank(user1);
        bob.transferAndCall(address(pool), 10 ether, abi.encode(user2, zkAddress));

        vm.expectEmit(true, true, false, true);
        emit SubmitDirectDeposit(user1, 1, user2, ZkAddress.parseZkAddress(zkAddress, 0), 9.9 gwei);
        vm.prank(user1);
        bob.transferAndCall(address(pool), 10 ether, abi.encode(user2, zkAddress));

        vm.prank(user1);
        vm.expectRevert("ZkBobAccounting: daily user direct deposit cap exceeded");
        bob.transferAndCall(address(pool), 10 ether, abi.encode(user2, zkAddress));

        for (uint256 i = 0; i < 2; i++) {
            ZkBobPool.DirectDeposit memory deposit;
            (deposit.user, deposit.amount, deposit.deposit, deposit.fee,, deposit.status,,) = pool.directDeposits(i);
            assertEq(deposit.user, user2);
            assertEq(deposit.amount, 10 ether);
            assertEq(deposit.deposit, 9.9 gwei);
            assertEq(deposit.fee, 0.1 gwei);
            assertEq(uint8(deposit.status), uint8(ZkBobPool.DirectDepositStatus.Pending));
        }
    }

    function testAppendDirectDeposits() public {
        _setUpDD();

        vm.prank(user1);
        bob.transferAndCall(address(pool), 10 ether, abi.encode(user2, zkAddress));

        vm.prank(user1);
        bob.transferAndCall(address(pool), 5 ether, abi.encode(user2, zkAddress));

        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        address verifier = address(pool.batch_deposit_verifier());
        uint256 outCommitment = _randFR();
        bytes memory data = abi.encodePacked(
            outCommitment,
            bytes10(0xda9ee1b1b651c87a76c2), // first deposit receiver zk address (42 bytes)
            bytes32(0xefe3e4b9b0a0e53e5b66ed19ad100afe5289ea732bfd5ac002969523f26e6f2f),
            uint64(9.9 gwei), // first deposit amount
            bytes10(0xda9ee1b1b651c87a76c2), // second deposit receiver zk address (42 bytes)
            bytes32(0xefe3e4b9b0a0e53e5b66ed19ad100afe5289ea732bfd5ac002969523f26e6f2f),
            uint64(4.9 gwei), // second deposit amount
            new bytes(14 * 50)
        );
        vm.expectCall(
            verifier,
            abi.encodeWithSelector(
                IBatchDepositVerifier.verifyProof.selector,
                [
                    uint256(keccak256(data)) % 21888242871839275222246405745257275088548364400416034343698204186575808495617
                ]
            )
        );
        vm.expectEmit(true, false, false, true);
        bytes memory message = abi.encodePacked(
            bytes4(0x02000001), // uint16(2) in little endian ++ MESSAGE_PREFIX_DIRECT_DEPOSIT_V1
            uint64(0), // first deposit nonce
            bytes10(0xda9ee1b1b651c87a76c2), // first deposit receiver zk address (42 bytes)
            bytes32(0xefe3e4b9b0a0e53e5b66ed19ad100afe5289ea732bfd5ac002969523f26e6f2f),
            uint64(9.9 gwei), // first deposit amount
            uint64(1), // second deposit nonce
            bytes10(0xda9ee1b1b651c87a76c2), // second deposit receiver zk address (42 bytes)
            bytes32(0xefe3e4b9b0a0e53e5b66ed19ad100afe5289ea732bfd5ac002969523f26e6f2f),
            uint64(4.9 gwei) // second deposit amount
        );
        emit Message(128, bytes32(0), message);
        vm.expectEmit(true, false, false, true);
        emit CompleteDirectDepositBatch(128, indices);
        vm.prank(user2);
        pool.appendDirectDeposits(_randFR(), indices, outCommitment, _randProof(), _randProof());
    }

    function testRefundDirectDeposit() public {
        _setUpDD();

        vm.prank(user1);
        bob.transferAndCall(address(pool), 10 ether + 1, abi.encode(user2, zkAddress));

        vm.prank(user1);
        bob.transferAndCall(address(pool), 5 ether + 1, abi.encode(user2, zkAddress));

        vm.expectRevert("ZkBobPool: direct deposit timeout not passed");
        pool.refundDirectDeposit(0);
        vm.expectRevert("ZkBobPool: direct deposit timeout not passed");
        pool.refundDirectDeposit(1);
        vm.expectRevert("ZkBobPool: direct deposit not pending");
        pool.refundDirectDeposit(2);

        deal(address(bob), user2, 0);

        vm.prank(user2);
        vm.expectEmit(true, false, false, true);
        emit RefundDirectDeposit(0, user2, 10 ether + 1);
        pool.refundDirectDeposit(0);
        vm.expectRevert("ZkBobPool: direct deposit not pending");
        pool.refundDirectDeposit(0);
        assertEq(bob.balanceOf(user2), 10 ether + 1);

        skip(2 days);

        vm.expectEmit(true, false, false, true);
        emit RefundDirectDeposit(1, user2, 5 ether + 1);
        pool.refundDirectDeposit(1);
        vm.expectRevert("ZkBobPool: direct deposit not pending");
        pool.refundDirectDeposit(1);
        assertEq(bob.balanceOf(user2), 15 ether + 2);
    }

    function _encodePermitDeposit(int256 _amount, uint256 _fee) internal returns (bytes memory) {
        uint256 expiry = block.timestamp + 1 hours;
        bytes32 nullifier = bytes32(_randFR());
        (uint8 v, bytes32 r, bytes32 s) = _signSaltedPermit(
            pk1, user1, address(pool), uint256(_amount + int256(_fee)), bob.nonces(user1), expiry, nullifier
        );
        bytes memory data = abi.encodePacked(
            ZkBobPool.transact.selector, nullifier, _randFR(), uint48(0), uint112(0), int64(_amount / 1 gwei)
        );
        for (uint256 i = 0; i < 17; i++) {
            data = abi.encodePacked(data, _randFR());
        }
        data = abi.encodePacked(
            data, uint16(3), uint16(72), uint64(_fee / 1 gwei), uint64(expiry), user1, bytes4(0x01000000), _randFR()
        );
        return abi.encodePacked(data, r, uint256(s) + (v == 28 ? (1 << 255) : 0));
    }

    function _encodeDeposit(int256 _amount, uint256 _fee) internal returns (bytes memory) {
        bytes32 nullifier = bytes32(_randFR());
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk1, ECDSA.toEthSignedMessageHash(nullifier));
        bytes memory data = abi.encodePacked(
            ZkBobPool.transact.selector, nullifier, _randFR(), uint48(0), uint112(0), int64(_amount / 1 gwei)
        );
        for (uint256 i = 0; i < 17; i++) {
            data = abi.encodePacked(data, _randFR());
        }
        data = abi.encodePacked(data, uint16(0), uint16(44), uint64(_fee / 1 gwei), bytes4(0x01000000), _randFR());
        return abi.encodePacked(data, r, uint256(s) + (v == 28 ? (1 << 255) : 0));
    }

    function _encodeWithdrawal(address _to, uint256 _amount, uint256 _nativeAmount) internal returns (bytes memory) {
        bytes memory data = abi.encodePacked(
            ZkBobPool.transact.selector,
            _randFR(),
            _randFR(),
            uint48(0),
            uint112(0),
            int64(-int256((_amount + 0.01 ether) / 1 gwei))
        );
        for (uint256 i = 0; i < 17; i++) {
            data = abi.encodePacked(data, _randFR());
        }
        return abi.encodePacked(
            data,
            uint16(2),
            uint16(72),
            uint64(0.01 ether / 1 gwei),
            uint64(_nativeAmount / 1 gwei),
            _to,
            bytes4(0x01000000),
            _randFR()
        );
    }

    function _encodeTransfer() internal returns (bytes memory) {
        bytes memory data = abi.encodePacked(
            ZkBobPool.transact.selector, _randFR(), _randFR(), uint48(0), uint112(0), int64(-0.01 ether / 1 gwei)
        );
        for (uint256 i = 0; i < 17; i++) {
            data = abi.encodePacked(data, _randFR());
        }
        return abi.encodePacked(data, uint16(1), uint16(44), uint64(0.01 ether / 1 gwei), bytes4(0x01000000), _randFR());
    }

    function _transact(bytes memory _data) internal {
        vm.prank(user2);
        (bool status,) = address(pool).call(_data);
        require(status, "transact() reverted");
    }

    function _transactReverted(bytes memory _data, bytes memory _revertReason) internal {
        vm.prank(user2);
        (bool status, bytes memory returnData) = address(pool).call(_data);
        assert(!status);
        assertEq(returnData, abi.encodeWithSignature("Error(string)", _revertReason));
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

    function _randFR() private returns (uint256) {
        return uint256(keccak256(abi.encode(gasleft())))
            % 21888242871839275222246405745257275088696311157297823662689037894645226208583;
    }

    function _randProof() private returns (uint256[8] memory) {
        return [_randFR(), _randFR(), _randFR(), _randFR(), _randFR(), _randFR(), _randFR(), _randFR()];
    }
}
