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
import "../../src/zkbob/ZkBobETHPool.sol";
import "../../src/zkbob/ZkBobDirectDepositQueue.sol";
import "../../src/BobToken.sol";
import "../../src/zkbob/manager/MutableOperatorManager.sol";
import "../shared/ForkTests.t.sol";
import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "../../src/zkbob/manager/kyc/SimpleKYCProviderManager.sol";
import "../../src/utils/WETHSeller.sol";

contract ZkBobETHPoolTest is AbstractMainnetForkTest {
    uint256 private constant initialRoot = 11469701942666298368112882412133877458305516134926649826543144744382391691533;

    address constant uniV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant uniV3Quoter = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    address constant uniV3Positions = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    bytes constant zkAddress = "QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mriHfN";

    bytes32 constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    ZkBobETHPool pool;
    ZkBobDirectDepositQueue queue;
    IWETH9 token;
    IOperatorManager operatorManager;
    IPermit2 permit2;

    event Message(uint256 indexed index, bytes32 indexed hash, bytes message);

    event SubmitDirectDeposit(
        address indexed sender,
        uint256 indexed nonce,
        address fallbackUser,
        ZkAddress.ZkAddress zkAddress,
        uint64 deposit
    );
    event RefundDirectDeposit(uint256 indexed nonce, address receiver, uint256 amount);
    event CompleteDirectDepositBatch(uint256[] indices);

    function setUp() public {
        vm.createSelectFork(forkRpcUrl, forkBlock);
        token = IWETH9(weth);
        permit2 = IPermit2(permit2Address);

        EIP1967Proxy poolProxy = new EIP1967Proxy(address(this), address(0xdead), "");
        EIP1967Proxy queueProxy = new EIP1967Proxy(address(this), address(0xdead), "");

        console2.log(weth, address(token));
        ZkBobETHPool impl =
        new ZkBobETHPool(0, address(token), new TransferVerifierMock(), new TreeUpdateVerifierMock(), new BatchDepositVerifierMock(), address(queueProxy), permit2Address);

        bytes memory initData = abi.encodeWithSelector(
            ZkBobETHPool.initialize.selector,
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
        pool = ZkBobETHPool(address(poolProxy));

        ZkBobDirectDepositQueue queueImpl = new ZkBobDirectDepositQueue(address(pool), address(token));
        queueProxy.upgradeTo(address(queueImpl));
        queue = ZkBobDirectDepositQueue(address(queueProxy));

        operatorManager = new MutableOperatorManager(user2, user3, "https://example.com");
        pool.setOperatorManager(operatorManager);

        WETHSeller wethSeller = new WETHSeller(weth);
        pool.setTokenSeller(address(wethSeller));
        queue.setOperatorManager(operatorManager);
        queue.setDirectDepositFee(0.1 gwei);
        queue.setDirectDepositTimeout(1 days);

        deal(weth, user1, 1 ether);
        vm.startPrank(user1);
        token.approve(permit2Address, type(uint256).max);
        token.approve(address(queue), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(permit2Address, type(uint256).max);
        token.approve(address(queue), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user3);
        token.approve(permit2Address, type(uint256).max);
        token.approve(address(queue), type(uint256).max);
        vm.stopPrank();
    }

    function testSimpleTransaction() public {
        bytes memory data1 = _encodePermitDeposit(0.5 ether, 0.01 ether);
        _transact(data1);

        bytes memory data2 = _encodeTransfer();
        _transact(data2);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(token.balanceOf(user3), 0.02 ether);
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
        deal(weth, user1, 10 ether);

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
        assertEq(token.balanceOf(user1), 0.49 ether);
        assertEq(token.balanceOf(address(pool)), 0.5 ether);
        assertEq(token.balanceOf(user3), 0.01 ether);
    }

    function testUsualDeposit() public {
        vm.prank(user1);
        token.approve(address(pool), 0.51 ether);

        bytes memory data = _encodeDeposit(0.5 ether, 0.01 ether);
        _transact(data);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(token.balanceOf(user1), 0.49 ether);
        assertEq(token.balanceOf(address(pool)), 0.5 ether);
        assertEq(token.balanceOf(user3), 0.01 ether);
    }

    function testWithdrawal() public {
        bytes memory data1 = _encodePermitDeposit(0.5 ether, 0.01 ether);
        _transact(data1);

        bytes memory data2 = _encodeWithdrawal(user1, 0.1 ether, 0 ether);
        _transact(data2);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(token.balanceOf(user1), 0.59 ether);
        assertEq(token.balanceOf(address(pool)), 0.39 ether);
        assertEq(token.balanceOf(user3), 0.02 ether);
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
        assertEq(token.balanceOf(user1), 0.1 ether);
        assertEq(token.balanceOf(dummy), 0.1 ether);
        assertEq(token.balanceOf(address(pool)), 0.17 ether);
        assertEq(token.balanceOf(user3), 0.03 ether);
        assertGt(user1.balance, 1 gwei);
        assertEq(user1.balance, quote2);
        assertGt(dummy.balance, 1 gwei);
        assertEq(dummy.balance, quote3);
    }

    function testRejectNegativeDeposits() public {
        bytes memory data1 = _encodePermitDeposit(0.99 ether, 0.01 ether);
        _transact(data1);

        bytes memory data2 = _encodePermitDeposit(-0.5 ether, 1 ether);
        _transactReverted(data2, "ZkBobPool: incorrect deposit amounts");

        vm.prank(user1);
        token.approve(address(pool), 0.5 ether);

        bytes memory data3 = _encodeDeposit(-0.5 ether, 1 ether);
        _transactReverted(data3, "ZkBobPool: incorrect deposit amounts");
    }

    function _setUpDD() internal {
        deal(user1, 100 ether);
        deal(address(token), user1, 100 ether);
        deal(address(token), user2, 100 ether);

        pool.setLimits(1, 2_000_000 ether, 200_000 ether, 200_000 ether, 20_000 ether, 20_000 ether, 25 ether, 10 ether);
        address[] memory users = new address[](1);
        users[0] = user1;
        pool.setUsersTier(1, users);

        queue.setDirectDepositFee(0.1 gwei);
    }

    function testDirectDepositSubmit() public {
        _setUpDD();

        vm.prank(user2);
        vm.expectRevert("ZkBobAccounting: single direct deposit cap exceeded");
        queue.directDeposit(user2, 10 ether, zkAddress);

        vm.startPrank(user1);
        vm.expectRevert("ZkBobDirectDepositQueue: direct deposit amount is too low");
        queue.directDeposit(user2, 0.01 ether, zkAddress);

        vm.expectRevert(ZkAddress.InvalidZkAddressLength.selector);
        queue.directDeposit(user2, 10 ether, bytes("invalid"));

        vm.expectRevert("ZkBobAccounting: single direct deposit cap exceeded");
        queue.directDeposit(user2, 15 ether, zkAddress);

        vm.expectEmit(true, true, false, true);
        emit SubmitDirectDeposit(user1, 0, user2, ZkAddress.parseZkAddress(zkAddress, 0), 9.9 gwei);
        queue.directDeposit(user2, 10 ether, zkAddress);

        vm.expectEmit(true, true, false, true);
        emit SubmitDirectDeposit(user1, 1, user2, ZkAddress.parseZkAddress(zkAddress, 0), 9.9 gwei);
        queue.directDeposit(user2, 10 ether, zkAddress);

        vm.expectRevert("ZkBobAccounting: daily user direct deposit cap exceeded");
        queue.directDeposit(user2, 10 ether, zkAddress);

        for (uint256 i = 0; i < 2; i++) {
            IZkBobDirectDeposits.DirectDeposit memory deposit = queue.getDirectDeposit(i);
            assertEq(deposit.fallbackReceiver, user2);
            assertEq(deposit.sent, 10 ether);
            assertEq(deposit.deposit, 9.9 gwei);
            assertEq(deposit.fee, 0.1 gwei);
            assertEq(uint8(deposit.status), uint8(IZkBobDirectDeposits.DirectDepositStatus.Pending));
        }
        vm.stopPrank();
    }

    function testAppendDirectDeposits() public {
        _setUpDD();

        vm.prank(user1);
        queue.directNativeDeposit{value: 10 ether}(user2, zkAddress);

        vm.prank(user1);
        queue.directNativeDeposit{value: 5 ether}(user2, zkAddress);

        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        address verifier = address(pool.batch_deposit_verifier());
        uint256 outCommitment = _randFR();
        bytes memory data = abi.encodePacked(
            outCommitment,
            bytes10(0xc2767ac851b6b1e19eda), // first deposit receiver zk address (42 bytes)
            bytes32(0x2f6f6ef223959602c05afd2b73ea8952fe0a10ad19ed665b3ee5a0b0b9e4e3ef),
            uint64(9.9 gwei), // first deposit amount
            bytes10(0xc2767ac851b6b1e19eda), // second deposit receiver zk address (42 bytes)
            bytes32(0x2f6f6ef223959602c05afd2b73ea8952fe0a10ad19ed665b3ee5a0b0b9e4e3ef),
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
        emit CompleteDirectDepositBatch(indices);
        bytes memory message = abi.encodePacked(
            bytes4(0x02000001), // uint16(2) in little endian ++ MESSAGE_PREFIX_DIRECT_DEPOSIT_V1
            uint64(0), // first deposit nonce
            bytes10(0xc2767ac851b6b1e19eda), // first deposit receiver zk address (42 bytes)
            bytes32(0x2f6f6ef223959602c05afd2b73ea8952fe0a10ad19ed665b3ee5a0b0b9e4e3ef),
            uint64(9.9 gwei), // first deposit amount
            uint64(1), // second deposit nonce
            bytes10(0xc2767ac851b6b1e19eda), // second deposit receiver zk address (42 bytes)
            bytes32(0x2f6f6ef223959602c05afd2b73ea8952fe0a10ad19ed665b3ee5a0b0b9e4e3ef),
            uint64(4.9 gwei) // second deposit amount
        );
        vm.expectEmit(true, false, false, true);
        emit Message(128, bytes32(0), message);
        vm.prank(user2);
        pool.appendDirectDeposits(_randFR(), indices, outCommitment, _randProof(), _randProof());
    }

    function testRefundDirectDeposit() public {
        _setUpDD();

        vm.prank(user1);
        queue.directNativeDeposit{value: 10 ether + 1}(user2, zkAddress);

        vm.prank(user1);
        queue.directNativeDeposit{value: 5 ether + 1}(user2, zkAddress);

        vm.expectRevert("ZkBobDirectDepositQueue: direct deposit timeout not passed");
        queue.refundDirectDeposit(0);
        vm.expectRevert("ZkBobDirectDepositQueue: direct deposit timeout not passed");
        queue.refundDirectDeposit(1);
        vm.expectRevert("ZkBobDirectDepositQueue: direct deposit not pending");
        queue.refundDirectDeposit(2);

        deal(address(token), user2, 0);

        vm.prank(user2);
        vm.expectEmit(true, false, false, true);
        emit RefundDirectDeposit(0, user2, 10 ether + 1);
        queue.refundDirectDeposit(0);
        vm.expectRevert("ZkBobDirectDepositQueue: direct deposit not pending");
        queue.refundDirectDeposit(0);
        assertEq(token.balanceOf(user2), 10 ether + 1);

        skip(2 days);

        vm.expectEmit(true, false, false, true);
        emit RefundDirectDeposit(1, user2, 5 ether + 1);
        queue.refundDirectDeposit(1);
        vm.expectRevert("ZkBobDirectDepositQueue: direct deposit not pending");
        queue.refundDirectDeposit(1);
        assertEq(token.balanceOf(user2), 15 ether + 2);
    }

    function testDepositForUserWithKYCPassed() public {
        uint8 tier = 254;
        ERC721PresetMinterPauserAutoId nft = new ERC721PresetMinterPauserAutoId("Test NFT", "tNFT", "http://nft.url/");

        SimpleKYCProviderManager manager = new SimpleKYCProviderManager(nft, tier);
        pool.setKycProvidersManager(manager);

        pool.setLimits(tier, 50 ether, 10 ether, 2 ether, 6 ether, 5 ether, 0, 0);
        address[] memory users = new address[](1);
        users[0] = user1;
        pool.setUsersTier(tier, users);

        nft.mint(user1);

        deal(weth, address(user1), 10 ether);

        bytes memory data = _encodePermitDeposit(4 ether, 0.01 ether);
        _transact(data);

        bytes memory data2 = _encodeWithdrawal(user1, 1 ether, 0 ether);
        _transact(data2);

        bytes memory data3 = _encodePermitDeposit(3 ether, 0.01 ether);
        _transactReverted(data3, "ZkBobAccounting: daily user deposit cap exceeded");

        bytes memory data4 = _encodeWithdrawal(user1, 2 ether, 0 ether);
        _transactReverted(data4, "ZkBobAccounting: daily withdrawal cap exceeded");

        assertEq(pool.getLimitsFor(user1).dailyUserDepositCapUsage, 4 gwei);
        assertEq(pool.getLimitsFor(user1).dailyWithdrawalCapUsage, 1.01 gwei); // 1 requested + 0.01 fees
    }

    function _encodePermitDeposit(int256 _amount, uint256 _fee) internal returns (bytes memory) {
        uint256 expiry = block.timestamp + 1 hours;
        bytes32 nullifier = bytes32(_randFR());
        (uint8 v, bytes32 r, bytes32 s) =
            _signSaltedPermit(pk1, user1, address(pool), uint256(_amount + int256(_fee)), expiry, nullifier);
        bytes memory data = abi.encodePacked(
            ZkBobETHPool.transact.selector, nullifier, _randFR(), uint48(0), uint112(0), int64(_amount / 1 gwei)
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
            ZkBobETHPool.transact.selector, nullifier, _randFR(), uint48(0), uint112(0), int64(_amount / 1 gwei)
        );
        for (uint256 i = 0; i < 17; i++) {
            data = abi.encodePacked(data, _randFR());
        }
        data = abi.encodePacked(data, uint16(0), uint16(44), uint64(_fee / 1 gwei), bytes4(0x01000000), _randFR());
        return abi.encodePacked(data, r, uint256(s) + (v == 28 ? (1 << 255) : 0));
    }

    function _encodeWithdrawal(address _to, uint256 _amount, uint256 _nativeAmount) internal returns (bytes memory) {
        bytes memory data = abi.encodePacked(
            ZkBobETHPool.transact.selector,
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
            ZkBobETHPool.transact.selector, _randFR(), _randFR(), uint48(0), uint112(0), int64(-0.01 ether / 1 gwei)
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

    function _randFR() private returns (uint256) {
        return uint256(keccak256(abi.encode(gasleft())))
            % 21888242871839275222246405745257275088696311157297823662689037894645226208583;
    }

    function _randProof() private returns (uint256[8] memory) {
        return [_randFR(), _randFR(), _randFR(), _randFR(), _randFR(), _randFR(), _randFR(), _randFR()];
    }
}
