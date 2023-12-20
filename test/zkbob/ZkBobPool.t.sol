// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "../shared/Env.t.sol";
import "../shared/ForkTests.t.sol";
import "../mocks/TransferVerifierMock.sol";
import "../mocks/TreeUpdateVerifierMock.sol";
import "../mocks/BatchDepositVerifierMock.sol";
import "../mocks/DummyImpl.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPool.sol";
import "../../src/zkbob/ZkBobDirectDepositQueue.sol";
import "../../src/zkbob/manager/MPCGuard.sol";
import "../../src/zkbob/manager/MutableOperatorManager.sol";
import "../../src/zkbob/manager/kyc/SimpleKYCProviderManager.sol";
import "../interfaces/IZkBobDirectDepositsAdmin.sol";
import "../interfaces/IZkBobPoolAdmin.sol";
import "../../src/interfaces/IERC677.sol";
import "../../src/zkbob/ZkBobPoolUSDC.sol";
import "../../src/zkbob/ZkBobDirectDepositQueueETH.sol";
import "../../src/zkbob/ZkBobPoolERC20.sol";
import "../../src/zkbob/ZkBobPoolBOB.sol";
import "../../src/zkbob/ZkBobPoolETH.sol";
import "../../src/infra/UniswapV3Seller.sol";
import {EnergyRedeemer} from "../../src/infra/EnergyRedeemer.sol";

abstract contract AbstractZkBobPoolTest is AbstractForkTest {
    address constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant uniV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant uniV3Quoter = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;

    uint256 constant initialRoot = 11469701942666298368112882412133877458305516134926649826543144744382391691533;

    enum PoolType {
        BOB,
        ETH,
        USDC,
        ERC20
    }
    enum PermitType {
        BOBPermit,
        Permit2,
        USDCPermit
    }

    uint256 D;
    address token;
    address weth;
    address tempToken;
    bool autoApproveQueue;
    PoolType poolType;
    PermitType permitType;
    uint256 denominator;
    uint256 precision;
    bool isMPC = false;

    bytes constant zkAddress = "QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mriHfN";

    bytes32 constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );
    bytes32 constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH = keccak256(
        "TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)"
    );

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

    IZkBobPoolAdmin pool;
    IZkBobDirectDepositsAdmin queue;
    IOperatorManager operatorManager;
    ZkBobAccounting accounting;

    function setUp() public {
        vm.createSelectFork(forkRpcUrl, forkBlock);

        EIP1967Proxy poolProxy = new EIP1967Proxy(address(this), address(0xdead), "");
        EIP1967Proxy queueProxy = new EIP1967Proxy(address(this), address(0xdead), "");

        ZkBobPool impl;
        if (poolType == PoolType.ETH) {
            impl = new ZkBobPoolETH(
                0,
                token,
                new TransferVerifierMock(),
                new TreeUpdateVerifierMock(),
                new BatchDepositVerifierMock(),
                address(queueProxy),
                permit2
            );
        } else if (poolType == PoolType.BOB) {
            impl = new ZkBobPoolBOB(
                0,
                token,
                new TransferVerifierMock(),
                new TreeUpdateVerifierMock(),
                new BatchDepositVerifierMock(),
                address(queueProxy)
            );
        } else if (poolType == PoolType.USDC) {
            impl = new ZkBobPoolUSDC(
                0,
                token,
                new TransferVerifierMock(),
                new TreeUpdateVerifierMock(),
                new BatchDepositVerifierMock(),
                address(queueProxy)
            );
        } else if (poolType == PoolType.ERC20) {
            impl = new ZkBobPoolERC20(
                0,
                token,
                new TransferVerifierMock(),
                new TreeUpdateVerifierMock(),
                new BatchDepositVerifierMock(),
                address(queueProxy),
                permit2,
                1_000_000_000
            );
        }

        bytes memory initData = abi.encodeWithSelector(ZkBobPool.initialize.selector, initialRoot);
        poolProxy.upgradeToAndCall(address(impl), initData);
        pool = IZkBobPoolAdmin(address(poolProxy));

        ZkBobDirectDepositQueue queueImpl;
        if (poolType == PoolType.ETH) {
            queueImpl = new ZkBobDirectDepositQueueETH(address(pool), token, denominator);
        } else {
            queueImpl = new ZkBobDirectDepositQueue(address(pool), token, denominator);
        }
        queueProxy.upgradeTo(address(queueImpl));
        queue = IZkBobDirectDepositsAdmin(address(queueProxy));

        accounting = new ZkBobAccounting(address(pool), precision);
        accounting.setLimits(
            0,
            1_000_000 ether / D / denominator,
            100_000 ether / D / denominator,
            100_000 ether / D / denominator,
            10_000 ether / D / denominator,
            10_000 ether / D / denominator,
            0,
            0
        );
        pool.setAccounting(accounting);
        if (isMPC) {
            address operatorEOA = makeAddr("operatorEOA");
            address operatorContract = address(new MPCGuard(operatorEOA, address(pool)));
            operatorManager = new MutableOperatorManager(operatorContract, user3, "https://example.com");
            address[] memory guardians = new address[](2);
            guardians[0] = makeAddr("guard2");
            guardians[1] = makeAddr("guard1");
            MPCGuard(operatorContract).setGuards(guardians);
            address[] memory users = new address[](2);
            users[0] = operatorContract;
            users[1] = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
            accounting.setLimits(
                1,
                2_000_000 ether / D / denominator,
                200_000 ether / D / denominator,
                200_000 ether / D / denominator,
                20_000 ether / D / denominator,
                20_000 ether / D / denominator,
                25 ether / D / denominator,
                10 ether / D / denominator
            );
            accounting.setUsersTier(1, users);
        } else {
            operatorManager = new MutableOperatorManager(user2, user3, "https://example.com");
        }
        pool.setOperatorManager(operatorManager);
        queue.setOperatorManager(operatorManager);
        queue.setDirectDepositFee(uint64(0.1 ether / D));
        queue.setDirectDepositTimeout(1 days);

        deal(token, user1, 1 ether / D);
        deal(token, user3, 0);
    }

    function testSimpleTransaction() public {
        bytes memory data1 = _encodePermitDeposit(int256(0.5 ether / D), 0.01 ether / D);
        _transact(data1);

        bytes memory data2 = _encodeTransfer(0.01 ether / D);
        _transact(data2);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(IERC20(token).balanceOf(user3), 0.02 ether / D);
    }

    function testGetters() public {
        assertEq(pool.pool_index(), 0);
        assertEq(pool.denominator(), denominator);

        bytes memory data1 = _encodePermitDeposit(int256(0.5 ether / D), 0.01 ether / D);
        _transact(data1);

        assertEq(pool.pool_index(), 128);

        bytes memory data2 = _encodeTransfer(0.01 ether / D);
        _transact(data2);

        assertEq(pool.pool_index(), 256);
    }

    function testAuthRights() public {
        vm.startPrank(user1);

        vm.expectRevert("ZkBobPool: not initializer");
        pool.initialize(0);
        vm.expectRevert("Ownable: caller is not the owner");
        pool.setOperatorManager(IOperatorManager(address(0)));
        try pool.tokenSeller() {
            vm.expectRevert("Ownable: caller is not the owner");
            pool.setTokenSeller(address(0));
        } catch {}
        vm.expectRevert("Ownable: caller is not the owner");
        accounting.setLimits(0, 0, 0, 0, 0, 0, 0, 0);
        vm.expectRevert("Ownable: caller is not the owner");
        accounting.setUsersTier(0, new address[](1));
        vm.expectRevert("Ownable: caller is not the owner");
        accounting.resetDailyLimits(0);

        vm.stopPrank();
    }

    function testUsersTiers() public {
        accounting.setLimits(
            1,
            2_000_000 ether / D / denominator,
            200_000 ether / D / denominator,
            200_000 ether / D / denominator,
            20_000 ether / D / denominator,
            20_000 ether / D / denominator,
            0,
            0
        );
        address[] memory users = new address[](1);
        users[0] = user2;
        accounting.setUsersTier(1, users);

        assertEq(accounting.getLimitsFor(user1).tier, 0);
        assertEq(accounting.getLimitsFor(user1).depositCap, 10_000 ether / D / denominator);
        assertEq(accounting.getLimitsFor(user2).tier, 1);
        assertEq(accounting.getLimitsFor(user2).depositCap, 20_000 ether / D / denominator);
    }

    function testResetDailyLimits() public {
        deal(token, user1, 10 ether / D);

        bytes memory data1 = _encodePermitDeposit(int256(5 ether / D), 0.01 ether / D);
        _transact(data1);

        bytes memory data2 = _encodeWithdrawal(user1, 4 ether / D, 0, 0);
        _transact(data2);

        assertEq(accounting.getLimitsFor(user1).dailyDepositCapUsage, 5 ether / D / denominator);
        assertEq(accounting.getLimitsFor(user1).dailyWithdrawalCapUsage, 4.01 ether / D / denominator);

        accounting.resetDailyLimits(0);

        assertEq(accounting.getLimitsFor(user1).dailyDepositCapUsage, 0);
        assertEq(accounting.getLimitsFor(user1).dailyWithdrawalCapUsage, 0);
    }

    function testSetOperatorManager() public {
        assertEq(address(pool.operatorManager()), address(operatorManager));

        IOperatorManager newOperatorManager = new MutableOperatorManager(user2, user3, "https://example.com");
        pool.setOperatorManager(newOperatorManager);

        assertEq(address(pool.operatorManager()), address(newOperatorManager));
    }

    function testPermitDeposit() public {
        bytes memory data = _encodePermitDeposit(int256(0.5 ether / D), 0.01 ether / D);
        _transact(data);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(IERC20(token).balanceOf(user1), 0.49 ether / D);
        assertEq(IERC20(token).balanceOf(address(pool)), 0.5 ether / D);
        assertEq(IERC20(token).balanceOf(user3), 0.01 ether / D);
    }

    function testMultiplePermitDeposits() public {
        for (uint256 i = 1; i < 10; i++) {
            deal(address(token), user1, 0.101 ether / D * i);
            bytes memory data = _encodePermitDeposit(int256(0.1 ether / D) * int256(i), 0.001 ether / D * i);
            _transact(data);
        }

        bytes memory data2 = _encodeTransfer(0.01 ether / D);
        _transact(data2);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(IERC20(token).balanceOf(user3), 0.055 ether / D);
    }

    function testUsualDeposit() public {
        vm.prank(user1);
        IERC20(token).approve(address(pool), 0.51 ether / D);

        bytes memory data = _encodeDeposit(int256(0.5 ether / D), 0.01 ether / D);
        _transact(data);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(IERC20(token).balanceOf(user1), 0.49 ether / D);
        assertEq(IERC20(token).balanceOf(address(pool)), 0.5 ether / D);
        assertEq(IERC20(token).balanceOf(user3), 0.01 ether / D);
    }

    function testWithdrawal() public {
        bytes memory data1 = _encodePermitDeposit(int256(0.5 ether / D), 0.01 ether / D);
        _transact(data1);

        bytes memory data2 = _encodeWithdrawal(user1, 0.1 ether / D, 0, 0);
        _transact(data2);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(IERC20(token).balanceOf(user1), 0.59 ether / D);
        assertEq(IERC20(token).balanceOf(address(pool)), 0.39 ether / D);
        assertEq(IERC20(token).balanceOf(user3), 0.02 ether / D);
    }

    function testForcedExit() public {
        bytes memory data = _encodePermitDeposit(int256(0.5 ether / D), 0.01 ether / D);
        _transact(data);

        uint256 nullifier = _randFR();
        pool.commitForcedExit(user2, user2, 0.4 ether / D / denominator, 128, nullifier, _randFR(), _randProof());
        uint256 exitStart = block.timestamp + 1 hours;
        uint256 exitEnd = block.timestamp + 24 hours;

        assertEq(IERC20(token).balanceOf(user2), 0);
        assertEq(pool.nullifiers(nullifier), 0);

        vm.expectRevert("ZkBobPool: invalid forced exit");
        pool.executeForcedExit(nullifier ^ 1, user2, user2, 0.4 ether / D / denominator, exitStart, exitEnd, false);

        vm.expectRevert("ZkBobPool: invalid forced exit");
        pool.executeForcedExit(nullifier, user2, user2, 0.4 ether / D / denominator, block.timestamp, exitEnd, false);

        vm.expectRevert("ZkBobPool: invalid caller");
        pool.executeForcedExit(nullifier, user2, user2, 0.4 ether / D / denominator, exitStart, exitEnd, false);

        vm.startPrank(user2);
        vm.expectRevert("ZkBobPool: exit not allowed");
        pool.executeForcedExit(nullifier, user2, user2, 0.4 ether / D / denominator, exitStart, exitEnd, false);

        skip(25 hours);
        vm.expectRevert("ZkBobPool: exit not allowed");
        pool.executeForcedExit(nullifier, user2, user2, 0.4 ether / D / denominator, exitStart, exitEnd, false);

        rewind(23 hours);
        pool.executeForcedExit(nullifier, user2, user2, 0.4 ether / D / denominator, exitStart, exitEnd, false);

        vm.expectRevert("ZkBobPool: doublespend detected");
        pool.executeForcedExit(nullifier, user2, user2, 0.4 ether / D / denominator, exitStart, exitEnd, false);

        assertEq(IERC20(token).balanceOf(user2), 0.4 ether / D);
        assertEq(pool.nullifiers(nullifier), 0xdeaddeaddeaddeaddeaddeaddeaddeaddeaddeaddeaddead0000000000000080);

        vm.expectRevert("ZkBobPool: doublespend detected");
        pool.commitForcedExit(user2, user2, 0.4 ether / D / denominator, 128, nullifier, _randFR(), _randProof());

        vm.stopPrank();
    }

    function testCancelForcedExit() public {
        bytes memory data = _encodePermitDeposit(int256(0.5 ether / D), 0.01 ether / D);
        _transact(data);

        uint256 nullifier = _randFR();
        pool.commitForcedExit(user2, user2, 0.4 ether / D / denominator, 128, nullifier, _randFR(), _randProof());
        uint256 exitStart = block.timestamp + 1 hours;
        uint256 exitEnd = block.timestamp + 24 hours;
        bytes32 hash = pool.committedForcedExits(nullifier);
        assertNotEq(hash, bytes32(0));

        vm.expectRevert("ZkBobPool: exit not expired");
        pool.executeForcedExit(nullifier, user2, user2, 0.4 ether / D / denominator, exitStart, exitEnd, true);
        vm.expectRevert("ZkBobPool: already exists");
        pool.commitForcedExit(user2, user2, 0.4 ether / D / denominator, 128, nullifier, _randFR(), _randProof());

        skip(12 hours);

        vm.expectRevert("ZkBobPool: exit not expired");
        pool.executeForcedExit(nullifier, user2, user2, 0.4 ether / D / denominator, exitStart, exitEnd, true);
        vm.expectRevert("ZkBobPool: already exists");
        pool.commitForcedExit(user2, user2, 0.4 ether / D / denominator, 128, nullifier, _randFR(), _randProof());

        skip(24 hours);

        pool.executeForcedExit(nullifier, user2, user2, 0.4 ether / D / denominator, exitStart, exitEnd, true);
        assertEq(pool.committedForcedExits(nullifier), bytes32(0));

        pool.commitForcedExit(user2, user2, 0.4 ether / D / denominator, 128, nullifier, _randFR(), _randProof());
        assertNotEq(pool.committedForcedExits(nullifier), bytes32(0));
        assertNotEq(pool.committedForcedExits(nullifier), hash);
    }

    function testRejectNegativeDeposits() public {
        bytes memory data1 = _encodePermitDeposit(int256(0.99 ether / D), 0.01 ether / D);
        _transact(data1);

        bytes memory data2 = _encodePermitDeposit(-int256(0.5 ether / D), 1 ether / D);
        _transactReverted(data2, "ZkBobPool: incorrect deposit amounts");

        vm.prank(user1);
        IERC20(token).approve(address(pool), 0.5 ether / D);

        bytes memory data3 = _encodeDeposit(-int256(0.5 ether / D), 1 ether / D);
        _transactReverted(data3, "ZkBobPool: incorrect deposit amounts");
    }

    function _setUpDD() internal {
        deal(user1, 100 ether / D);
        deal(user2, 100 ether / D);
        deal(address(token), user1, 100 ether / D);
        deal(address(token), user2, 100 ether / D);

        accounting.setLimits(
            1,
            2_000_000 ether / D / denominator,
            200_000 ether / D / denominator,
            200_000 ether / D / denominator,
            20_000 ether / D / denominator,
            20_000 ether / D / denominator,
            25 ether / D / denominator,
            10 ether / D / denominator
        );
        address[] memory users = new address[](1);
        users[0] = user1;
        accounting.setUsersTier(1, users);

        queue.setDirectDepositFee(uint64(0.1 ether / D / pool.denominator()));

        if (autoApproveQueue) {
            vm.prank(user1);
            IERC20(token).approve(address(queue), type(uint256).max);
            vm.prank(user2);
            IERC20(token).approve(address(queue), type(uint256).max);
        }
    }

    function testDirectDepositSubmit() public {
        _setUpDD();

        vm.startPrank(user2);
        vm.expectRevert("ZkBobAccounting: single direct deposit cap exceeded");
        _directDeposit(10 ether / D, user2, zkAddress);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("ZkBobDirectDepositQueue: direct deposit amount is too low");
        _directDeposit(0.01 ether / D, user2, zkAddress);

        vm.expectRevert(ZkAddress.InvalidZkAddressLength.selector);
        _directDeposit(10 ether / D, user2, "invalid");

        vm.expectRevert("ZkBobAccounting: single direct deposit cap exceeded");
        _directDeposit(15 ether / D, user2, zkAddress);

        ZkAddress.ZkAddress memory parsedZkAddress = ZkAddress.parseZkAddress(zkAddress, 0);
        vm.expectEmit(true, true, false, true);
        emit SubmitDirectDeposit(user1, 0, user2, parsedZkAddress, uint64(9.9 ether / D / denominator));
        _directDeposit(10 ether / D, user2, zkAddress);

        if (!autoApproveQueue) {
            IERC20(token).approve(address(queue), 10 ether / D);
        }
        vm.expectEmit(true, true, false, true);
        emit SubmitDirectDeposit(user1, 1, user2, parsedZkAddress, uint64(9.9 ether / D / denominator));
        queue.directDeposit(user2, 10 ether / D, zkAddress);

        vm.expectRevert("ZkBobAccounting: daily user direct deposit cap exceeded");
        _directDeposit(10 ether / D, user2, zkAddress);

        for (uint256 i = 0; i < 2; i++) {
            IZkBobDirectDeposits.DirectDeposit memory deposit = queue.getDirectDeposit(i);
            assertEq(deposit.fallbackReceiver, user2);
            assertEq(deposit.sent, 10 ether / D);
            assertEq(deposit.deposit, uint64(9.9 ether / D / denominator));
            assertEq(deposit.fee, 0.1 ether / D / denominator);
            assertEq(uint8(deposit.status), uint8(IZkBobDirectDeposits.DirectDepositStatus.Pending));
        }
        vm.stopPrank();
    }

    function testAppendDirectDeposits() public {
        _setUpDD();

        vm.startPrank(user1);
        _directDeposit(10 ether / D, user2, zkAddress);
        _directDeposit(5 ether / D, user2, zkAddress);
        vm.stopPrank();

        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        address verifier = address(pool.batch_deposit_verifier());
        uint256 outCommitment = _randFR();
        bytes memory data = abi.encodePacked(
            outCommitment,
            bytes10(0xc2767ac851b6b1e19eda), // first deposit receiver zk address (42 bytes)
            bytes32(0x2f6f6ef223959602c05afd2b73ea8952fe0a10ad19ed665b3ee5a0b0b9e4e3ef),
            uint64(9.9 ether / D / denominator), // first deposit amount
            bytes10(0xc2767ac851b6b1e19eda), // second deposit receiver zk address (42 bytes)
            bytes32(0x2f6f6ef223959602c05afd2b73ea8952fe0a10ad19ed665b3ee5a0b0b9e4e3ef),
            uint64(4.9 ether / D / denominator), // second deposit amount
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
            uint64(9.9 ether / D / denominator), // first deposit amount
            uint64(1), // second deposit nonce
            bytes10(0xc2767ac851b6b1e19eda), // second deposit receiver zk address (42 bytes)
            bytes32(0x2f6f6ef223959602c05afd2b73ea8952fe0a10ad19ed665b3ee5a0b0b9e4e3ef),
            uint64(4.9 ether / D / denominator) // second deposit amount
        );
        vm.expectEmit(true, false, false, true);
        emit Message(128, bytes32(0), message);
        vm.prank(user2);
        pool.appendDirectDeposits(_randFR(), indices, outCommitment, _randProof(), _randProof());
    }

    function testRefundDirectDeposit() public {
        _setUpDD();

        vm.startPrank(user1);
        _directDeposit(10 ether / D + 1, user2, zkAddress);
        _directDeposit(5 ether / D + 1, user2, zkAddress);
        vm.stopPrank();

        vm.expectRevert("ZkBobDirectDepositQueue: direct deposit timeout not passed");
        queue.refundDirectDeposit(0);
        vm.expectRevert("ZkBobDirectDepositQueue: direct deposit timeout not passed");
        queue.refundDirectDeposit(1);
        vm.expectRevert("ZkBobDirectDepositQueue: direct deposit not pending");
        queue.refundDirectDeposit(2);

        deal(address(token), user2, 0);

        vm.prank(user2);
        vm.expectEmit(true, false, false, true);
        emit RefundDirectDeposit(0, user2, 10 ether / D + 1);
        queue.refundDirectDeposit(0);
        vm.expectRevert("ZkBobDirectDepositQueue: direct deposit not pending");
        queue.refundDirectDeposit(0);
        assertEq(IERC20(token).balanceOf(user2), 10 ether / D + 1);

        skip(2 days);

        vm.expectEmit(true, false, false, true);
        emit RefundDirectDeposit(1, user2, 5 ether / D + 1);
        queue.refundDirectDeposit(1);
        vm.expectRevert("ZkBobDirectDepositQueue: direct deposit not pending");
        queue.refundDirectDeposit(1);
        assertEq(IERC20(token).balanceOf(user2), 15 ether / D + 2);
    }

    function testDepositForUserWithKYCPassed() public {
        uint8 tier = 254;
        ERC721PresetMinterPauserAutoId nft = new ERC721PresetMinterPauserAutoId("Test NFT", "tNFT", "http://nft.url/");

        SimpleKYCProviderManager manager = new SimpleKYCProviderManager(nft, tier);
        accounting.setKycProvidersManager(manager);

        accounting.setLimits(
            tier,
            50 ether / D / denominator,
            10 ether / D / denominator,
            2 ether / D / denominator,
            6 ether / D / denominator,
            5 ether / D / denominator,
            0,
            0
        );
        address[] memory users = new address[](1);
        users[0] = user1;
        accounting.setUsersTier(tier, users);

        nft.mint(user1);

        deal(address(token), address(user1), 10 ether / D);

        bytes memory data = _encodePermitDeposit(int256(4 ether / D), 0.01 ether / D);
        _transact(data);

        bytes memory data2 = _encodeWithdrawal(user1, 1 ether / D, 0, 0);
        _transact(data2);

        bytes memory data3 = _encodePermitDeposit(int256(3 ether / D), 0.01 ether / D);
        _transactReverted(data3, "ZkBobAccounting: daily user deposit cap exceeded");

        bytes memory data4 = _encodeWithdrawal(user1, 2 ether / D, 0, 0);
        _transactReverted(data4, "ZkBobAccounting: daily withdrawal cap exceeded");

        assertEq(accounting.getLimitsFor(user1).dailyUserDepositCapUsage, 4 ether / D / denominator);
        assertEq(accounting.getLimitsFor(user1).dailyWithdrawalCapUsage, 1.01 ether / D / denominator); // 1 requested + 0.01 fees
    }

    function _quoteNativeSwap(uint256 _amount) internal returns (uint256) {
        if (poolType == PoolType.ETH) {
            return _amount;
        }
        return pool.tokenSeller().quoteSellForETH(_amount);
    }

    function testNativeWithdrawal() public {
        if (poolType != PoolType.ETH) {
            // enable token swaps for ETH
            address addr;
            if (tempToken == address(0)) {
                addr = address(new UniswapV3Seller(uniV3Router, uniV3Quoter, token, 500, address(0), 0));
            } else {
                addr = address(new UniswapV3Seller(uniV3Router, uniV3Quoter, token, 100, tempToken, 500));
            }
            pool.setTokenSeller(addr);
            assertEq(address(uint160(uint256(vm.load(address(pool), bytes32(uint256(11)))))), addr);
        }

        vm.deal(user1, 0);

        bytes memory data1 = _encodePermitDeposit(int256(0.99 ether / D), 0.01 ether / D);
        _transact(data1);

        // user1 withdraws 0.4 BOB, 0.3 BOB gets converted to ETH
        uint256 quote2 = _quoteNativeSwap(0.3 ether / D);
        bytes memory data2 = _encodeWithdrawal(user1, 0.4 ether / D, 0.3 ether / D, 0);
        _transact(data2);

        // user1 withdraws 0.2 BOB, trying to convert 0.3 BOB to ETH
        bytes memory data4 = _encodeWithdrawal(user1, 0.2 ether / D, 0.3 ether / D, 0);
        vm.prank(user2);
        (bool status, bytes memory returnData) = address(pool).call(data4);
        assert(!status);
        assertEq(returnData, stdError.arithmeticError);

        address dummy = address(new DummyImpl(0));
        uint256 quote3 = _quoteNativeSwap(0.3 ether / D);
        bytes memory data3 = _encodeWithdrawal(dummy, 0.4 ether / D, 0.3 ether / D, 0);
        _transact(data3);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);

        assertEq(IERC20(token).balanceOf(user3), 0.03 ether / D);
        assertEq(IERC20(token).balanceOf(address(pool)), 0.17 ether / D);
        assertEq(IERC20(token).balanceOf(user1), 0.1 ether / D);
        assertGt(user1.balance, 1 gwei);
        assertEq(user1.balance, quote2);

        assertEq(dummy.balance, 0);
        if (token == weth) {
            assertEq(IERC20(token).balanceOf(dummy), 0.4 ether / D);
        } else {
            assertEq(IERC20(token).balanceOf(dummy), 0.1 ether / D);
            assertGt(IERC20(weth).balanceOf(dummy), 1 gwei);
            assertEq(IERC20(weth).balanceOf(dummy), quote3);
        }
    }

    function testOperatorCannotAvoidWithdrawalLimit() public {
        deal(token, user1, 1_000_000 ether / D);

        accounting.setLimits(
            0,
            1_000_000 ether / D / denominator,
            500_000 ether / D / denominator,
            500_000 ether / D / denominator,
            500_000 ether / D / denominator,
            500_000 ether / D / denominator,
            0,
            0
        );
        bytes memory data1 = _encodePermitDeposit(int256(250_000 ether / D), 0.01 ether / D);
        _transact(data1);
        accounting.setLimits(
            0,
            1_000_000 ether / D / denominator,
            100_000 ether / D / denominator,
            100_000 ether / D / denominator,
            10_000 ether / D / denominator,
            10_000 ether / D / denominator,
            0,
            0
        );
        bytes memory data2 = _encodeTransfer(200_000 ether / D);
        _transactReverted(data2, "ZkBobAccounting: daily withdrawal cap exceeded");

        bytes memory data3 = _encodeTransfer(20_000 ether / D);
        _transact(data3);

        vm.prank(user3);
        pool.withdrawFee(user2, user3);
        assertEq(IERC20(token).balanceOf(user3), 20_000.01 ether / D);
        assertEq(accounting.getLimitsFor(user2).dailyWithdrawalCapUsage, 20_000 ether / D / denominator);
    }

    function testEnergyRedemption() public {
        deal(token, user1, 2_000_000 ether / D);

        for (uint256 i = 0; i < 100; i++) {
            bytes memory data1 = _encodePermitDeposit(int256(2_500 ether / D), 0.01 ether / D);
            _transact(data1);

            skip(6 hours + 1);
        }

        IERC20 rewardToken = IERC20(new ERC20Mock("Reward token", "RT", address(this), 1_000_000 ether));
        IEnergyRedeemer redeemer = new EnergyRedeemer(address(pool), address(rewardToken), 1e16, 1e12);
        rewardToken.transfer(address(redeemer), 1_000_000 ether);
        pool.setEnergyRedeemer(redeemer);

        // 1e18 energy ~= account balance of 100k BOB across 10k tx indices
        bytes memory data2 = _encodeWithdrawal(user1, 0, 0, 1e18);
        _transact(data2);

        // max weekly tvl ~= 200k
        // max weekly tx count ~= 28
        // 1e18 energy * (1e16 * 1e12 / 1e18) / 2e5 / 28 ~= 1785e18 reward tokens
        assertApproxEqAbs(rewardToken.balanceOf(user1), 1785 ether, 200 ether);
    }

    function _encodeDeposit(int256 _amount, uint256 _fee) internal returns (bytes memory) {
        bytes32 nullifier = bytes32(_randFR());
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk1, ECDSA.toEthSignedMessageHash(nullifier));
        bytes memory data = abi.encodePacked(
            ZkBobPool.transact.selector, //4
            nullifier, //32
            _randFR(), //32
            uint48(0), //6
            uint112(0), //14
            int64(_amount / int256(denominator)) //8
        ); //96
        for (uint256 i = 0; i < 17; i++) {
            //32*17 = 544
            data = abi.encodePacked(data, _randFR());
        }
        data = abi.encodePacked(
            data,
            uint16(0) //2
        ); //642
        bytes memory memo = abi.encodePacked(
            uint16(44), //2
            uint64(_fee / denominator), //8
            bytes4(0x01000000), //4
            _randFR() //32
        );
        data = abi.encodePacked(data, memo); //688
        data = abi.encodePacked(data, r, uint256(s) + (v == 28 ? (1 << 255) : 0)); //688+64=752
        return data;
    }

    function _encodeWithdrawal(
        address _to,
        uint256 _amount,
        uint256 _nativeAmount,
        uint256 _energyAmount
    )
        internal
        returns (bytes memory)
    {
        bytes memory data = abi.encodePacked(
            ZkBobPool.transact.selector,
            _randFR(),
            _randFR(),
            uint48(0),
            -int112(int256(_energyAmount)),
            int64(-int256((_amount / denominator) + 0.01 ether / D / denominator))
        );
        for (uint256 i = 0; i < 17; i++) {
            data = abi.encodePacked(data, _randFR());
        }
        return abi.encodePacked(
            data,
            uint16(2),
            uint16(72),
            uint64(0.01 ether / D / denominator),
            uint64(_nativeAmount / denominator),
            _to,
            bytes4(0x01000000),
            _randFR()
        );
    }

    function _encodeTransfer(uint256 _fee) internal returns (bytes memory) {
        bytes memory data = abi.encodePacked(
            ZkBobPool.transact.selector, _randFR(), _randFR(), uint48(0), uint112(0), -int64(uint64(_fee / denominator))
        );
        for (uint256 i = 0; i < 17; i++) {
            data = abi.encodePacked(data, _randFR());
        }
        return abi.encodePacked(data, uint16(1), uint16(44), uint64(_fee / denominator), bytes4(0x01000000), _randFR());
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

    function _randFR() internal returns (uint256) {
        return uint256(keccak256(abi.encode(gasleft())))
            % 21888242871839275222246405745257275088696311157297823662689037894645226208583;
    }

    function _randProof() internal returns (uint256[8] memory) {
        return [_randFR(), _randFR(), _randFR(), _randFR(), _randFR(), _randFR(), _randFR(), _randFR()];
    }

    function _encodePermitDeposit(int256 _amount, uint256 _fee) internal returns (bytes memory) {
        if (permitType == PermitType.Permit2) {
            vm.prank(user1);
            IERC20(token).approve(permit2, type(uint256).max);
        }

        uint256 expiry = block.timestamp + 1 hours;
        bytes32 nullifier = bytes32(_randFR());

        bytes32 digest;
        if (permitType == PermitType.BOBPermit) {
            digest = _digestSaltedPermit(user1, address(pool), uint256(_amount + int256(_fee)), expiry, nullifier);
        } else if (permitType == PermitType.Permit2) {
            digest = _digestPermit2(user1, address(pool), uint256(_amount + int256(_fee)), expiry, nullifier);
        } else if (permitType == PermitType.USDCPermit) {
            digest = _digestUSDCPermit(user1, address(pool), uint256(_amount + int256(_fee)), expiry, nullifier);
        }
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk1, digest);

        bytes memory data = abi.encodePacked(
            ZkBobPool.transact.selector,
            nullifier,
            _randFR(),
            uint48(0),
            uint112(0),
            int64(_amount / int256(denominator))
        );
        for (uint256 i = 0; i < 17; i++) {
            data = abi.encodePacked(data, _randFR());
        }
        data = abi.encodePacked(
            data,
            uint16(3),
            uint16(72),
            uint64(_fee / denominator),
            uint64(expiry),
            user1,
            bytes4(0x01000000),
            _randFR()
        );
        return abi.encodePacked(data, r, uint256(s) + (v == 28 ? (1 << 255) : 0));
    }

    function _digestSaltedPermit(
        address _holder,
        address _spender,
        uint256 _value,
        uint256 _expiry,
        bytes32 _salt
    )
        internal
        view
        returns (bytes32)
    {
        uint256 nonce = IERC20Permit(token).nonces(_holder);
        return ECDSA.toTypedDataHash(
            IERC20Permit(token).DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    IERC20Permit(token).SALTED_PERMIT_TYPEHASH(), _holder, _spender, _value, nonce, _expiry, _salt
                )
            )
        );
    }

    function _digestPermit2(
        address _holder,
        address _spender,
        uint256 _value,
        uint256 _expiry,
        bytes32 _salt
    )
        internal
        view
        returns (bytes32)
    {
        return ECDSA.toTypedDataHash(
            IPermit2(permit2).DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    PERMIT_TRANSFER_FROM_TYPEHASH,
                    keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, token, _value)),
                    _spender,
                    _salt,
                    _expiry
                )
            )
        );
    }

    function _digestUSDCPermit(
        address _holder,
        address _spender,
        uint256 _value,
        uint256 _expiry,
        bytes32 _salt
    )
        internal
        view
        returns (bytes32)
    {
        return ECDSA.toTypedDataHash(
            IERC20Permit(token).DOMAIN_SEPARATOR(),
            keccak256(abi.encode(TRANSFER_WITH_AUTHORIZATION_TYPEHASH, _holder, _spender, _value, 0, _expiry, _salt))
        );
    }

    function _directDeposit(uint256 amount, address fallbackUser, bytes memory _zkAddress) internal {
        if (poolType == PoolType.ETH) {
            ZkBobDirectDepositQueueETH(address(queue)).directNativeDeposit{value: amount}(fallbackUser, _zkAddress);
        } else if (poolType == PoolType.BOB) {
            IERC677(token).transferAndCall(address(queue), amount, abi.encode(fallbackUser, _zkAddress));
        } else {
            queue.directDeposit(fallbackUser, amount, _zkAddress);
        }
    }
}

contract ZkBobPoolBOBPolygonTest is AbstractZkBobPoolTest, AbstractPolygonForkTest {
    constructor() {
        D = 1;
        token = address(0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B);
        weth = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
        tempToken = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        poolType = PoolType.BOB;
        autoApproveQueue = false;
        permitType = PermitType.BOBPermit;
        denominator = 1_000_000_000;
        precision = 1_000_000_000;
    }
}

contract ZkBobPoolETHMainnetTest is AbstractZkBobPoolTest, AbstractMainnetForkTest {
    constructor() {
        D = 1;
        token = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        tempToken = address(0);
        poolType = PoolType.ETH;
        autoApproveQueue = false;
        permitType = PermitType.Permit2;
        denominator = 1_000_000_000;
        precision = 1_000_000_000;
    }
}

contract ZkBobPoolDAIMainnetTest is AbstractZkBobPoolTest, AbstractMainnetForkTest {
    constructor() {
        D = 1;
        token = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        tempToken = address(0);
        poolType = PoolType.ERC20;
        autoApproveQueue = true;
        permitType = PermitType.Permit2;
        denominator = 1_000_000_000;
        precision = 1_000_000_000;
    }
}

contract ZkBobPoolUSDCPolygonTest is AbstractZkBobPoolTest, AbstractPolygonForkTest {
    constructor() {
        D = 10 ** 12;
        token = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        weth = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
        tempToken = address(0);
        poolType = PoolType.USDC;
        autoApproveQueue = true;
        permitType = PermitType.USDCPermit;
        denominator = 1;
        precision = 1_000_000;
    }
}
