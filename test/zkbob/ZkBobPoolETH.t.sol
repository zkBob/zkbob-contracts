// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "../shared/Env.t.sol";
import "../mocks/TransferVerifierMock.sol";
import "../mocks/TreeUpdateVerifierMock.sol";
import "../mocks/BatchDepositVerifierMock.sol";
import "../mocks/DummyImpl.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPoolETH.sol";
import "../../src/zkbob/ZkBobDirectDepositQueue.sol";
import "../../src/BobToken.sol";
import "../../src/zkbob/manager/MutableOperatorManager.sol";
import "../shared/ForkTests.t.sol";
import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "../../src/zkbob/manager/kyc/SimpleKYCProviderManager.sol";
import "../../src/zkbob/ZkBobDirectDepositQueueETH.sol";
import "./ZkBobPool.t.sol";

contract ZkBobPoolETHTest is AbstractZkBobPoolTest {
    uint256 private constant initialRoot = 11469701942666298368112882412133877458305516134926649826543144744382391691533;

    IPermit2 permit2;

    function setUp() public {
        vm.createSelectFork(forkRpcUrl, forkBlock);
        token = weth;
        permit2 = IPermit2(permit2Address);

        EIP1967Proxy poolProxy = new EIP1967Proxy(address(this), address(0xdead), "");
        EIP1967Proxy queueProxy = new EIP1967Proxy(address(this), address(0xdead), "");

        console2.log(weth, address(token));
        ZkBobPoolETH impl =
        new ZkBobPoolETH(0, address(token), new TransferVerifierMock(), new TreeUpdateVerifierMock(), new BatchDepositVerifierMock(), address(queueProxy), permit2Address);

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
        pool = IZkBobPoolAdmin(payable(address(poolProxy)));

        ZkBobDirectDepositQueueETH queueImpl = new ZkBobDirectDepositQueueETH(address(pool), address(token));
        queueProxy.upgradeTo(address(queueImpl));
        queue = IZkBobDirectDepositsAdmin(address(queueProxy));

        operatorManager = new MutableOperatorManager(user2, user3, "https://example.com");
        pool.setOperatorManager(operatorManager);

        queue.setOperatorManager(operatorManager);
        queue.setDirectDepositFee(0.1 gwei);
        queue.setDirectDepositTimeout(1 days);

        deal(weth, user1, 1 ether);
        vm.startPrank(user1);
        IERC20(token).approve(permit2Address, type(uint256).max);
        IERC20(token).approve(address(queue), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        IERC20(token).approve(permit2Address, type(uint256).max);
        IERC20(token).approve(address(queue), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user3);
        IERC20(token).approve(permit2Address, type(uint256).max);
        IERC20(token).approve(address(queue), type(uint256).max);
        vm.stopPrank();
    }

    function testSimpleTransactionPermit2() public {
        bytes memory data2 = _encodePermitDeposit(0.3 ether, 0.003 ether);
        bytes memory data1 = _encodePermitDeposit(0.2 ether, 0.007 ether);

        _transact(data1);
        _transact(data2);

        bytes memory data3 = _encodeTransfer();
        _transact(data3);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(IERC20(token).balanceOf(user3), 0.02 ether);
    }

    function testAuthRights() public {
        vm.startPrank(user1);

        vm.expectRevert("ZkBobPool: not initializer");
        pool.initialize(0, 0, 0, 0, 0, 0, 0, 0);
        vm.expectRevert("Ownable: caller is not the owner");
        pool.setOperatorManager(IOperatorManager(address(0)));
        vm.expectRevert("Ownable: caller is not the owner");
        pool.setLimits(0, 0, 0, 0, 0, 0, 0, 0);
        vm.expectRevert("Ownable: caller is not the owner");
        pool.setUsersTier(0, new address[](1));
        vm.expectRevert("Ownable: caller is not the owner");
        pool.resetDailyLimits(0);

        vm.stopPrank();
    }

    function testNativeWithdrawal() public {
        vm.deal(user1, 0);

        bytes memory data1 = _encodePermitDeposit(0.99 ether, 0.01 ether);
        _transact(data1);

        // user1 withdraws 0.4 BOB, 0.3 BOB gets converted to ETH
        uint256 quote2 = 0.3 ether;
        bytes memory data2 = _encodeWithdrawal(user1, 0.4 ether, 0.3 ether);
        _transact(data2);

        address dummy = address(new DummyImpl(0));
        uint256 quote3 = 0.3 ether;
        bytes memory data3 = _encodeWithdrawal(dummy, 0.4 ether, 0.3 ether);
        _transact(data3);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(IERC20(token).balanceOf(user1), 0.1 ether);
        assertEq(IERC20(token).balanceOf(dummy), 0.1 ether);
        assertEq(IERC20(token).balanceOf(address(pool)), 0.17 ether);
        assertEq(IERC20(token).balanceOf(user3), 0.03 ether);
        assertGt(user1.balance, 1 gwei);
        assertEq(user1.balance, quote2);
        assertGt(dummy.balance, 1 gwei);
        assertEq(dummy.balance, quote3);
    }

    function _transferAndCall(uint256 amount, address fallbackUser, bytes memory _zkAddress) internal override {
        queue.directNativeDeposit{value: amount}(fallbackUser, _zkAddress);
    }

    function _encodePermitDeposit(int256 _amount, uint256 _fee) internal override returns (bytes memory) {
        uint256 expiry = block.timestamp + 1 hours;
        bytes32 nullifier = bytes32(_randFR());
        (uint8 v, bytes32 r, bytes32 s) =
            _signSaltedPermit(pk1, user1, address(pool), uint256(_amount + int256(_fee)), 0, expiry, nullifier);
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

    function _getEIP712Hash(
        IPermit2.PermitTransferFrom memory permit,
        address spender
    )
        internal
        view
        returns (bytes32 h)
    {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                permit2.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_FROM_TYPEHASH,
                        keccak256(
                            abi.encode(TOKEN_PERMISSIONS_TYPEHASH, permit.permitted.token, permit.permitted.amount)
                        ),
                        spender,
                        permit.nonce,
                        permit.deadline
                    )
                )
            )
        );
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
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({token: weth, amount: _value}),
            nonce: uint256(_salt),
            deadline: _expiry
        });
        return vm.sign(_pk, _getEIP712Hash(permit, _spender));
    }
}
