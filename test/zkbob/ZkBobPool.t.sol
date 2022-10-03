// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "../shared/Env.t.sol";
import "../mocks/TransferVerifierMock.sol";
import "../mocks/TreeUpdateVerifierMock.sol";
import "../mocks/DummyImpl.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPool.sol";
import "../../src/BobToken.sol";
import "../../src/zkbob/manager/MutableOperatorManager.sol";
import "../../src/utils/UniswapV3Seller.sol";

contract ZkBobPoolTest is Test {
    uint256 private constant initialRoot = 11469701942666298368112882412133877458305516134926649826543144744382391691533;

    ZkBobPool pool;
    BobToken bob;

    function setUp() public {
        EIP1967Proxy bobProxy = new EIP1967Proxy(address(this), mockImpl, "");
        BobToken bobImpl = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(bobImpl));
        bob = BobToken(address(bobProxy));
        bob.updateMinter(address(this), true, true);

        ZkBobPool impl = new ZkBobPool(0, address(bob), new TransferVerifierMock(), new TreeUpdateVerifierMock());
        EIP1967Proxy poolProxy = new EIP1967Proxy(address(this), address(impl), abi.encodeWithSelector(
            ZkBobPool.initialize.selector, initialRoot,
            1_000_000 ether, 100_000 ether, 100_000 ether, 10_000 ether, 10_000 ether
        ));
        pool = ZkBobPool(address(poolProxy));

        pool.setOperatorManager(new MutableOperatorManager(user2, user3, "https://example.com"));

        bob.mint(address(user1), 1 ether);
    }

    function testSimpleTransaction() public {
        bytes memory data1 = _encodePermitDeposit(0.5 ether);
        _transact(data1);

        bytes memory data2 = _encodeTransfer();
        _transact(data2);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(bob.balanceOf(user3), 0.02 ether);
    }

    function testPermitDeposit() public {
        bytes memory data = _encodePermitDeposit(0.5 ether);
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

        bytes memory data = _encodeDeposit(0.5 ether);
        _transact(data);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(bob.balanceOf(user1), 0.49 ether);
        assertEq(bob.balanceOf(address(pool)), 0.5 ether);
        assertEq(bob.balanceOf(user3), 0.01 ether);
    }

    function testWithdrawal() public {
        bytes memory data1 = _encodePermitDeposit(0.5 ether);
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
        vm.createSelectFork(forkRpcUrl);

        // create BOB-USDC 0.05% pool at Uniswap V3
        deal(usdc, address(this), 1e9);
        IERC20(usdc).approve(uniV3Positions, 1e9);
        INonfungiblePositionManager(uniV3Positions).createAndInitializePoolIfNecessary(
            usdc, address(bob), 500, TickMath.getSqrtRatioAtTick(276320)
        );
        INonfungiblePositionManager(uniV3Positions).mint(
            INonfungiblePositionManager.MintParams({
                token0: usdc,
                token1: address(bob),
                fee: 500,
                tickLower: 276320,
                tickUpper: 276330,
                amount0Desired: 1e9,
                amount1Desired: 0,
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

        bytes memory data1 = _encodePermitDeposit(0.99 ether);
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

        bytes memory data1 = _encodePermitDeposit(10000 ether);
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

    function _encodePermitDeposit(uint256 _amount) internal returns (bytes memory) {
        uint256 expiry = block.timestamp + 1 hours;
        bytes32 nullifier = bytes32(_randFR());
        (uint8 v, bytes32 r, bytes32 s) =
            _signSaltedPermit(pk1, user1, address(pool), _amount + 0.01 ether, bob.nonces(user1), expiry, nullifier);
        bytes memory data = abi.encodePacked(
            ZkBobPool.transact.selector, nullifier, _randFR(), uint48(0), uint112(0), int64(int256(_amount / 1 gwei))
        );
        for (uint256 i = 0; i < 17; i++) {
            data = abi.encodePacked(data, _randFR());
        }
        data = abi.encodePacked(
            data,
            uint16(3),
            uint16(80),
            uint64(0.01 ether / 1 gwei),
            uint64(expiry),
            user1,
            bytes32(_randFR()),
            bytes12(bytes32(_randFR()))
        );
        return abi.encodePacked(data, r, uint256(s) + (v == 28 ? (1 << 255) : 0));
    }

    function _encodeDeposit(uint256 _amount) internal returns (bytes memory) {
        bytes32 nullifier = bytes32(_randFR());
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk1, ECDSA.toEthSignedMessageHash(nullifier));
        bytes memory data = abi.encodePacked(
            ZkBobPool.transact.selector, nullifier, _randFR(), uint48(0), uint112(0), int64(int256(_amount / 1 gwei))
        );
        for (uint256 i = 0; i < 17; i++) {
            data = abi.encodePacked(data, _randFR());
        }
        data = abi.encodePacked(
            data, uint16(0), uint16(48), uint64(0.01 ether / 1 gwei), _randFR(), bytes8(bytes32(_randFR()))
        );
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
            uint16(80),
            uint64(0.01 ether / 1 gwei),
            uint64(_nativeAmount / 1 gwei),
            _to,
            _randFR(),
            bytes12(bytes32(_randFR()))
        );
    }

    function _encodeTransfer() internal returns (bytes memory) {
        bytes memory data = abi.encodePacked(
            ZkBobPool.transact.selector, _randFR(), _randFR(), uint48(0), uint112(0), int64(-0.01 ether / 1 gwei)
        );
        for (uint256 i = 0; i < 17; i++) {
            data = abi.encodePacked(data, _randFR());
        }
        return abi.encodePacked(
            data, uint16(1), uint16(48), uint64(0.01 ether / 1 gwei), _randFR(), bytes8(bytes32(_randFR()))
        );
    }

    function _transact(bytes memory _data) internal {
        vm.prank(user2);
        (bool status,) = address(pool).call(_data);
        require(status, "transact() reverted");
    }

    function _signSaltedPermit(
        uint256 _pk,
        address _holder,
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 _expiry,
        bytes32 _salt
    ) internal returns (uint8 v, bytes32 r, bytes32 s) {
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
}
