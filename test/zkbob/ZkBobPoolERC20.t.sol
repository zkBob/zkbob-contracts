// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../../src/utils/UniswapV3Seller.sol";
import "../../src/zkbob/ZkBobPoolBOB.sol";
import "./ZkBobPool.t.sol";

contract ZkBobPoolBOBTest is AbstractZkBobPoolTest {
    uint256 private constant initialRoot = 11469701942666298368112882412133877458305516134926649826543144744382391691533;
    BobToken bob;

    function setUp() public {
        EIP1967Proxy bobProxy = new EIP1967Proxy(address(this), mockImpl, "");
        BobToken bobImpl = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(bobImpl));
        bob = BobToken(address(bobProxy));
        bob.updateMinter(address(this), true, true);

        EIP1967Proxy poolProxy = new EIP1967Proxy(address(this), address(0xdead), "");
        EIP1967Proxy queueProxy = new EIP1967Proxy(address(this), address(0xdead), "");

        ZkBobPoolBOB impl =
        new ZkBobPoolBOB(0, address(bob), new TransferVerifierMock(), new TreeUpdateVerifierMock(), new BatchDepositVerifierMock(), address(queueProxy));

        bytes memory initData = abi.encodeWithSelector(
            ZkBobPool.initialize.selector,
            initialRoot,
            1_000_000 ether,
            100_000 ether,
            100_000 ether,
            10_000 ether,
            10_000 ether,
            0,
            0
        );
        poolProxy.upgradeToAndCall(address(impl), initData);
        pool = IZkBobPoolAdmin(address(poolProxy));

        ZkBobDirectDepositQueue queueImpl = new ZkBobDirectDepositQueue(address(pool), address(bob));
        queueProxy.upgradeTo(address(queueImpl));
        queue = IZkBobDirectDepositsAdmin(address(queueProxy));

        operatorManager = new MutableOperatorManager(user2, user3, "https://example.com");
        pool.setOperatorManager(operatorManager);
        queue.setOperatorManager(operatorManager);
        queue.setDirectDepositFee(0.1 gwei);
        queue.setDirectDepositTimeout(1 days);

        bob.mint(address(user1), 1 ether);
        token = address(bob);
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
        address addr = address(new UniswapV3Seller(uniV3Router, uniV3Quoter, address(bob), 500, usdc, 500));
        pool.setTokenSeller(addr);
        assertEq(address(uint160(uint256(vm.load(address(pool), bytes32(uint256(11)))))), addr);
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

    function _transferAndCall(uint256 amount, address fallbackUser, bytes memory _zkAddress) internal override {
        bob.transferAndCall(address(queue), amount, abi.encode(fallbackUser, _zkAddress));
    }

    function _encodePermitDeposit(int256 _amount, uint256 _fee) internal override returns (bytes memory) {
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
}
