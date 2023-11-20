// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {AbstractForkTest, AbstractPolygonForkTest} from "../shared/ForkTests.t.sol";
import {IZkBobDirectDepositsAdmin} from "../interfaces/IZkBobDirectDepositsAdmin.sol";
import {IZkBobPoolAdmin} from "../interfaces/IZkBobPoolAdmin.sol";
import {IERC20Permit} from "../../src/interfaces/IERC20Permit.sol";
import {IPermit2} from "../../src/interfaces/IPermit2.sol";
import {ZkBobSequencer} from "../../src/zkbob/sequencer/ZkBobSequencer.sol";
import {ZkBobAccounting} from "../../src/zkbob/utils/ZkBobAccounting.sol";
import {EIP1967Proxy} from "../../src/proxy/EIP1967Proxy.sol";
import {ZkBobPool} from "../../src/zkbob/ZkBobPool.sol";
import {ZkBobPoolETH} from "../../src/zkbob/ZkBobPoolETH.sol";
import {ZkBobPoolBOB} from "../../src/zkbob/ZkBobPoolBOB.sol";
import {ZkBobPoolUSDC} from "../../src/zkbob/ZkBobPoolUSDC.sol";
import {ZkBobPoolERC20} from "../../src/zkbob/ZkBobPoolERC20.sol";
import {ZkBobDirectDepositQueue} from "../../src/zkbob/ZkBobDirectDepositQueue.sol";
import {ZkBobDirectDepositQueueETH} from "../../src/zkbob/ZkBobDirectDepositQueueETH.sol";
import {TransferVerifierMock} from "../mocks/TransferVerifierMock.sol";
import {TreeUpdateVerifierMock} from "../mocks/TreeUpdateVerifierMock.sol";
import {BatchDepositVerifierMock} from "../mocks/BatchDepositVerifierMock.sol";
import {ZkBobSequencer} from "../../src/zkbob/sequencer/ZkBobSequencer.sol";
import {MutableOperatorManager} from "../../src/zkbob/manager/MutableOperatorManager.sol";
import {PriorityOperation} from "../../src/zkbob/sequencer/PriorityQueue.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC677} from "../../src/interfaces/IERC677.sol";
import "../shared/Env.t.sol";

import "forge-std/console2.sol";

abstract contract AbstractZkBobPoolSequencerTest is AbstractForkTest {
    bytes constant zkAddress = "QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mriHfN";
    address constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    uint256 constant initialRoot =
        11469701942666298368112882412133877458305516134926649826543144744382391691533;

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

    address token;
    PoolType poolType;
    uint256 denominator;
    uint256 precision;
    uint256 D;

    PermitType permitType;
    IZkBobPoolAdmin pool;
    IZkBobDirectDepositsAdmin queue;
    ZkBobSequencer sequencer;
    MutableOperatorManager operatorManager;
    ZkBobAccounting accounting;

    address prover1 = makeAddr("prover1");
    address prover2 = makeAddr("prover2");

    function setUp() public {
        vm.createSelectFork(forkRpcUrl, forkBlock);

        EIP1967Proxy poolProxy = new EIP1967Proxy(
            address(this),
            address(0xdead),
            ""
        );
        EIP1967Proxy queueProxy = new EIP1967Proxy(
            address(this),
            address(0xdead),
            ""
        );

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

        bytes memory initData = abi.encodeWithSelector(
            ZkBobPool.initialize.selector,
            initialRoot
        );
        poolProxy.upgradeToAndCall(address(impl), initData);
        pool = IZkBobPoolAdmin(address(poolProxy));

        ZkBobDirectDepositQueue queueImpl;
        if (poolType == PoolType.ETH) {
            queueImpl = new ZkBobDirectDepositQueueETH(
                address(pool),
                token,
                denominator
            );
        } else {
            queueImpl = new ZkBobDirectDepositQueue(
                address(pool),
                token,
                denominator
            );
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
        sequencer = new ZkBobSequencer(address(pool), denominator);
        operatorManager = new MutableOperatorManager(
            address(sequencer),
            address(sequencer),
            "https://example.com"
        );
        pool.setOperatorManager(operatorManager);
        queue.setOperatorManager(operatorManager);
        queue.setDirectDepositFee(uint64(0.1 ether / D));
        queue.setDirectDepositTimeout(1 days);

        deal(token, user1, 10 ether / D);
        deal(token, user2, 10 ether / D);
        deal(token, user3, 0);
    }

    function testEmptyQueue() public {
        vm.expectRevert();
        sequencer.pendingOperation();
    }

    function testCommitProveDeposit() external {
        deposit(int256(3), uint64(1), uint64(2), prover1);
    }

    function testCommitProveTransfer() external {
        deposit(int256(5), uint64(1), uint64(2), prover1);

        uint64 proxyFee = uint64(1);
        uint64 proverFee = uint64(1);
        (bytes memory commitData, bytes memory proveData) = _encodeTransfer(proxyFee, proverFee, prover1);
        
        startHoax(prover1);
        (bool success, ) = address(sequencer).call(abi.encodePacked(ZkBobSequencer.commit.selector, commitData));
        assertTrue(success);

        uint256 feeBefore = sequencer.accumulatedFees(prover1);
        (success, ) = address(sequencer).call(abi.encodePacked(ZkBobSequencer.prove.selector, proveData));
        uint256 feeAfter = sequencer.accumulatedFees(prover1);

        assertTrue(success);
        assertTrue(feeAfter == feeBefore + proxyFee + proverFee);

        vm.stopPrank();
    }

    function testAnyoneCanSubmitTreeProofAfterGracePeriod() external {
        int256 amount = int256(3);
        uint64 proxyFee = uint64(1);
        uint64 proverFee = uint64(2);
        (bytes memory commitData, bytes memory proveData) = _encodeDeposit(amount, proxyFee, proverFee, prover1);

        approve(user1, amount, proxyFee, proverFee);

        uint256 prover1FeeBefore = sequencer.accumulatedFees(prover1);
        uint256 prover2FeeBefore = sequencer.accumulatedFees(prover2);

        hoax(prover1);
        (bool success, )  = address(sequencer).call(abi.encodePacked(ZkBobSequencer.commit.selector, commitData));
        assertTrue(success);
        assertEq(sequencer.accumulatedFees(prover1), prover1FeeBefore + proxyFee);

        vm.warp(block.timestamp + sequencer.PROXY_GRACE_PERIOD() + 1);

        hoax(prover2);    
        (success, )  = address(sequencer).call(abi.encodePacked(ZkBobSequencer.prove.selector, proveData));
        assertTrue(success);
        assertEq(sequencer.accumulatedFees(prover1), prover1FeeBefore + proxyFee);
        assertEq(sequencer.accumulatedFees(prover2), prover2FeeBefore + proverFee);
    }

    function testCanSkipExpiredOperation() external {
        int256 amount = int256(3);
        uint64 proxyFee = uint64(1);
        uint64 proverFee = uint64(2);
        (bytes memory firstCommitData, bytes memory firstProveData) = _encodeDeposit(amount, proxyFee, proverFee, prover1);
        (bytes memory secondCommitData, bytes memory secondProveData) = _encodeDeposit(amount, proxyFee, proverFee, prover2);
        
        approve(user1, amount, proxyFee * 2, proverFee);

        uint256 prover1FeeBefore = sequencer.accumulatedFees(prover1);
        uint256 prover2FeeBefore = sequencer.accumulatedFees(prover2);
        
        hoax(prover1);
        (bool success, ) = address(sequencer).call(abi.encodePacked(ZkBobSequencer.commit.selector, firstCommitData));
        assertTrue(success);

        hoax(prover2);    
        (success, ) = address(sequencer).call(abi.encodePacked(ZkBobSequencer.commit.selector, secondCommitData));
        assertTrue(success);

        vm.warp(block.timestamp + sequencer.EXPIRATION_TIME() + 1);

        hoax(prover1);
        (success, ) = address(sequencer).call(abi.encodePacked(ZkBobSequencer.prove.selector, firstProveData));
        assertFalse(success);

        hoax(prover2);    
        (success, ) = address(sequencer).call(abi.encodePacked(ZkBobSequencer.prove.selector, secondProveData));
        assertTrue(success);

        assertEq(sequencer.accumulatedFees(prover1), prover1FeeBefore + proxyFee);
        assertEq(sequencer.accumulatedFees(prover2), prover2FeeBefore + proxyFee + proverFee);
    }

    function testCanWithdrawFees() external {
        deposit(int256(1), uint64(12), uint64(27), prover1);
        deposit(int256(1), uint64(3), uint64(7), prover2);

        uint256 prover1FeeBefore = sequencer.accumulatedFees(prover1);
        uint256 prover1BalanceBefore = IERC20(token).balanceOf(prover1);
        uint256 prover2FeeBefore = sequencer.accumulatedFees(prover2);
        uint256 prover2BalanceBefore = IERC20(token).balanceOf(prover2);

        assertEq(prover1FeeBefore, uint64(39));
        assertEq(prover2FeeBefore, uint64(10));
        
        hoax(prover1);
        sequencer.withdrawFees();

        hoax(prover2);
        sequencer.withdrawFees();

        uint256 prover1FeeAfter = sequencer.accumulatedFees(prover1);
        uint256 prover1BalanceAfter = IERC20(token).balanceOf(prover1);
        uint256 prover2FeeAfter = sequencer.accumulatedFees(prover2);
        uint256 prover2BalanceAfter = IERC20(token).balanceOf(prover2);

        assertEq(prover1FeeAfter, 0);
        assertEq(prover1BalanceAfter, prover1BalanceBefore + prover1FeeBefore * denominator);

        assertEq(prover2FeeAfter, 0);
        assertEq(prover2BalanceAfter, prover2BalanceBefore + prover2FeeBefore * denominator);
    }

    //user1 is the dapp user, user2 is the chosen prover
    function testPermitDepositCommitAndProve() external {
        uint256 amount = uint256(9_960_000_000);
        uint64 proxyFee = uint64(10_000_000);
        uint64 proverFee = uint64(30_000_000);

        uint256 proxyAccFeesBefore = pool.accumulatedFee(user2);

        IERC20 tokenContract = IERC20(token);

        uint256 prover1BalanceBefore = sequencer.accumulatedFees(prover1);

        uint256 userBalanceBefore = tokenContract.balanceOf(user1);

        (bytes memory commitData, bytes memory proveData) = _encodePermitDeposit(
            amount,
            prover1,
            proxyFee,
            proverFee
        );

        vm.startPrank(prover1);

        
        (bool success, ) = address(sequencer).call(
            (abi.encodePacked(ZkBobSequencer.commit.selector, commitData))
        );

        // assertEq(sequencerBalanceBefore + proxyFee, tokenContract.balanceOf(address(this)));

        (success, ) = address(sequencer).call(
            (abi.encodePacked(ZkBobSequencer.prove.selector, proveData))
        );

        assertTrue(success);

        assertEq(proverFee+ proxyFee, sequencer.accumulatedFees(prover1) - prover1BalanceBefore);

        vm.stopPrank();
    }

    function testCommitProveDirectDeposits() public {
        _setUpDD();

        vm.startPrank(user1);
        _directDeposit(10 ether / D, user2, zkAddress);
        _directDeposit(5 ether / D, user2, zkAddress);
        vm.stopPrank();

        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        uint256 outCommitment = _randFR();
        
        vm.startPrank(prover1);
        uint256[8] memory batchProof = _randProof();
        sequencer.commitDirectDeposits(indices, outCommitment, batchProof);

        sequencer.proveDirectDeposit(_randFR(), indices, outCommitment, batchProof, _randProof());
    }

    function testCantCommitAlreadyCommitedDirectDeposits() public {
        _setUpDD();

        vm.startPrank(user1);
        _directDeposit(1 ether / D, user2, zkAddress);
        _directDeposit(2 ether / D, user2, zkAddress);
        _directDeposit(3 ether / D, user2, zkAddress);
        _directDeposit(4 ether / D, user2, zkAddress);
        vm.stopPrank();

        uint256[] memory firstBatchIndices = new uint256[](3);
        firstBatchIndices[0] = 0;
        firstBatchIndices[1] = 1;
        firstBatchIndices[2] = 2;
        uint256 firstBatchCommitment = _randFR();
        uint256[8] memory firstBatchProof = _randProof();

        vm.prank(prover1);
        sequencer.commitDirectDeposits(firstBatchIndices, firstBatchCommitment, firstBatchProof);

        uint256[] memory secondBatchIndices = new uint256[](2);
        secondBatchIndices[0] = 2;
        secondBatchIndices[1] = 3;
        uint256 secondBatchCommitment = _randFR();
        uint256[8] memory secondBatchProof = _randProof();

        vm.prank(prover2);
        vm.expectRevert();
        sequencer.commitDirectDeposits(secondBatchIndices, secondBatchCommitment, secondBatchProof);

        sequencer.proveDirectDeposit(_randFR(), firstBatchIndices, firstBatchCommitment, firstBatchProof, _randProof());

        uint256[] memory thirdBatchIndices = new uint256[](1);
        thirdBatchIndices[0] = 3;
        uint256 thirdBatchCommitment = _randFR();
        uint256[8] memory thirdBatchProof = _randProof();

        vm.prank(prover2);
        sequencer.commitDirectDeposits(thirdBatchIndices, thirdBatchCommitment, thirdBatchProof);

        sequencer.proveDirectDeposit(_randFR(), thirdBatchIndices, thirdBatchCommitment, thirdBatchProof, _randProof());
    }

    function approve(address user, int256 amount, uint64 proxyFee, uint64 proverFee) internal {
        vm.startPrank(user);
        IERC20(token).approve(address(sequencer), proxyFee * denominator);
        IERC20(token).approve(address(pool), (uint256(amount) + proverFee) * denominator);
        vm.stopPrank();
    }

    function deposit(int256 amount, uint64 proxyFee, uint64 proverFee, address prover) internal {
        (bytes memory commitData, bytes memory proveData) = _encodeDeposit(amount, proxyFee, proverFee, prover);
        
        approve(user1, amount, proxyFee, proverFee);
        
        uint256 feeBefore = sequencer.accumulatedFees(prover);
        startHoax(prover);
        (bool success, ) = address(sequencer).call(abi.encodePacked(ZkBobSequencer.commit.selector, commitData));
        assertTrue(success);
        assertEq(sequencer.accumulatedFees(prover), feeBefore + proxyFee);
        
        (success, ) = address(sequencer).call(abi.encodePacked(ZkBobSequencer.prove.selector, proveData));
        assertTrue(success);
        assertEq(sequencer.accumulatedFees(prover), feeBefore + proxyFee + proverFee);

        vm.stopPrank();
    }

    function _encodeDeposit(
        int256 _amount,
        uint64 _proxyFee,
        uint64 _proverFee,
        address _prover
    ) internal view returns (bytes memory commitData, bytes memory proveData) {
        bytes32 nullifier = bytes32(_randFR());
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            pk1,
            ECDSA.toEthSignedMessageHash(nullifier)
        );
        commitData = abi.encodePacked(
            nullifier,
            _randFR(),
            uint48(0),
            uint112(0),
            int64(_amount)
        );
        for (uint256 i = 0; i < 8; i++) {
            commitData = abi.encodePacked(commitData, _randFR());
        }

        proveData = commitData;
        for (uint256 i = 0; i < 9; i++) {
            proveData = abi.encodePacked(proveData, _randFR());
        }

        bytes memory memo = _encodeMemo(_prover, _proxyFee, _proverFee);
        bytes memory txTypeAndMemo = abi.encodePacked(
            uint16(0),
            uint16(memo.length),
            memo
        );
        txTypeAndMemo = abi.encodePacked(
            txTypeAndMemo,
            r,
            uint256(s) + (v == 28 ? (1 << 255) : 0)
        );
        commitData = abi.encodePacked(commitData, txTypeAndMemo);
        proveData = abi.encodePacked(proveData, txTypeAndMemo);
    }

    function _encodePermits(
        bytes memory data,
        bytes32 proxyDigest,
        bytes32 proverDigest
    ) internal pure returns (bytes memory) {
        (uint8 vProxy, bytes32 rProxy, bytes32 sProxy) = vm.sign(
            pk1,
            proxyDigest
        );
        (uint8 vProver, bytes32 rProver, bytes32 sProver) = vm.sign(
            pk1,
            proverDigest
        );

        return
            abi.encodePacked(
                data,
                _encodePermitSignature(vProver, rProver, sProver), //64
                _encodePermitSignature(vProxy, rProxy, sProxy) //64
            );
    }

    function _encodePermitSignature(
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(r,uint256(s) + (v == 28 ? (1 << 255) : 0));
    }

    function _encodePermitDeposit(
        uint256 _amount,
        address _prover,
        uint64 _proxyFee,
        uint64 _proverFee
    ) internal returns (bytes memory commitData, bytes memory proveData) {
        if (permitType == PermitType.Permit2) {
            vm.prank(user1);
            IERC20(token).approve(permit2, type(uint256).max);
        }

        uint256 expiry = block.timestamp + 1 hours;
        // bytes32 nullifier = bytes32(_randFR());
        bytes32 nullifier = 0x0000000000000000000000000000000000000000000000000000000000000000;

        bytes32 proverPermitDigest;
        bytes32 proxyPermitDigest;
        if (permitType == PermitType.BOBPermit) {
            uint256 nonce = IERC20Permit(token).nonces(user1);

            proxyPermitDigest = _digestSaltedPermitWithNonce(
                user1,
                address(sequencer),
                _proxyFee * denominator, 
                nonce,
                expiry,
                nullifier
            );

        
            proverPermitDigest = _digestSaltedPermitWithNonce(
                user1,
                address(pool),
                uint256(_amount + uint256(_proverFee)) * denominator, 
                ++ nonce,
                expiry,
                nullifier
            );
        } else if (permitType == PermitType.Permit2) {
            proxyPermitDigest = _digestPermit2(
                user1,
                address(sequencer),
                _proxyFee,
                expiry,
                nullifier
            );
            proverPermitDigest = _digestPermit2(
                user1,
                address(pool),
                uint256(_amount + uint256(_proverFee)),
                expiry,
                nullifier
            );
        } else if (permitType == PermitType.USDCPermit) {
            proxyPermitDigest = _digestUSDCPermit(
                user1,
                address(sequencer),
                _proxyFee,
                expiry,
                nullifier
            );
            proverPermitDigest = _digestUSDCPermit(
                user1,
                address(pool),
                uint256(_amount + uint256(_proverFee)),
                expiry,
                nullifier
            );
        }

        commitData = abi.encodePacked(
            // ZkBobSequencer.commit.selector, //4
            nullifier, //32 nullifier
            _randFR(), //32 out_commit
            uint48(0), //index 6
            uint112(0), //energy 14
            uint64(_amount) //token amount 8
        );
        for (uint256 i = 0; i < 8; i++) {
            commitData = abi.encodePacked(commitData, new bytes(32)); //tx proof(8)*32 = 256
        }

        proveData = commitData;

        for (uint256 i = 0; i < 9; i++) {
            proveData = abi.encodePacked(proveData, _randFR()); //tx proof(8)*8 + root(1)*8 + tree proof(8)*8 = 136
        }

        bytes memory memo = abi.encodePacked( //100 byte
            // fixed size 20+8+8+8+20 = 64
            bytes20(_prover), //20
            _proxyFee, //8
            _proverFee, //8
            uint64(expiry), //memo: expiry //8
            user1, //memo:holder //20
            // message 4 + 32 = 36
            bytes4(0x01000000), // 1 item
            _randFR() //32
        ); //out account mock

        commitData = abi.encodePacked(
            commitData,
            uint16(3), // 4 txType PermittableDeposit
            uint16(memo.length), // length 2 bytes , value = 64+ 12 +32 =12
            memo // 76
        );

        proveData = abi.encodePacked(
            proveData,
            uint16(3), // 4 txType PermittableDeposit
            uint16(memo.length), // length 2 bytes , value = 64+ 12 +32 =12
            memo // 76
        );

        commitData = _encodePermits(
            commitData,
            proxyPermitDigest, //64
            proverPermitDigest //64
        );

        proveData = _encodePermits(
            proveData,
            proxyPermitDigest,
            proverPermitDigest
        );

    }

    bytes32 constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 constant PERMIT_TRANSFER_FROM_TYPEHASH =
        keccak256(
            "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
        );
    bytes32 constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH =
        keccak256(
            "TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)"
        );


    function testSig()external{
        uint64 expiry = 1671415261;
        uint64 proxyFee = uint64(10_000_000);
        bytes32 nullifier =  0x0000000000000000000000000000000000000000000000000000000000000000;

        bytes32 proxyPermitDigest = _digestSaltedPermit(
                user1,
                address(sequencer),
                proxyFee,
                expiry,
                nullifier
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            pk1,
            proxyPermitDigest
        );

        bytes memory encodedSig = _encodePermitSignature(v,r,s);
        address poolToken = pool.token();
        
        vm.prank(address(sequencer));
        IERC20Permit(poolToken).receiveWithSaltedPermit(
            user1,
            uint256(proxyFee),
            expiry,
            bytes32(nullifier),
            v,
            r,
            s
        );

    }
    function _digestSaltedPermit(
        address _holder,
        address _spender,
        uint256 _value,
        uint256 _expiry,
        bytes32 _salt
    ) internal view returns (bytes32) {
        uint256 nonce = IERC20Permit(token).nonces(_holder);
        return
            ECDSA.toTypedDataHash(
                IERC20Permit(token).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        IERC20Permit(token).SALTED_PERMIT_TYPEHASH(),
                        _holder,
                        _spender,
                        _value,
                        nonce,
                        _expiry,
                        _salt
                    )
                )
            );
    }

    function _digestSaltedPermitWithNonce(
        address _holder,
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 _expiry,
        bytes32 _salt
    ) internal view returns (bytes32) {
        return
            ECDSA.toTypedDataHash(
                IERC20Permit(token).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        IERC20Permit(token).SALTED_PERMIT_TYPEHASH(),
                        _holder,
                        _spender,
                        _value,
                        _nonce,
                        _expiry,
                        _salt
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
    ) internal view returns (bytes32) {
        return
            ECDSA.toTypedDataHash(
                IPermit2(permit2).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_FROM_TYPEHASH,
                        keccak256(
                            abi.encode(
                                TOKEN_PERMISSIONS_TYPEHASH,
                                token,
                                _value
                            )
                        ),
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
    ) internal view returns (bytes32) {
        return
            ECDSA.toTypedDataHash(
                IERC20Permit(token).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        TRANSFER_WITH_AUTHORIZATION_TYPEHASH,
                        _holder,
                        _spender,
                        _value,
                        0,
                        _expiry,
                        _salt
                    )
                )
            );
    }

    function _encodeTransfer(
        uint64 _proxyFee,
        uint64 _proverFee,
        address _prover
    ) internal view returns (bytes memory commitData, bytes memory proveData) {
        commitData = abi.encodePacked(
            _randFR(),
            _randFR(),
            uint48(0),
            uint112(0),
            -int64(_proxyFee + _proverFee)
        );
        for (uint256 i = 0; i < 8; i++) {
            commitData = abi.encodePacked(commitData, _randFR());
        }

        proveData = commitData;
        for (uint256 i = 0; i < 9; i++) {
            proveData = abi.encodePacked(proveData, _randFR());
        }

        bytes memory memo = _encodeMemo(_prover, _proxyFee, _proverFee);
        bytes memory txTypeAndMemo = abi.encodePacked(
            uint16(1),
            uint16(memo.length),
            memo
        );
        commitData = abi.encodePacked(commitData, txTypeAndMemo);
        proveData = abi.encodePacked(proveData, txTypeAndMemo);
    }

    function _encodeMemo(
        address prover,
        uint64 proxyFee,
        uint64 proverFee
    ) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                bytes20(prover),
                bytes8(proxyFee),
                bytes8(proverFee),
                bytes4(0x01000000),
                _randFR()
            );
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

    function _randFR() internal view returns (uint256) {
        return
            uint256(keccak256(abi.encode(gasleft()))) %
            21888242871839275222246405745257275088696311157297823662689037894645226208583;
    }

    function _randProof() internal view returns (uint256[8] memory) {
        return [_randFR(), _randFR(), _randFR(), _randFR(), _randFR(), _randFR(), _randFR(), _randFR()];
    }

    function bytesToHexString(
        bytes memory data
    ) public pure returns (string memory) {
        bytes memory hexString = new bytes(2 * data.length);

        for (uint256 i = 0; i < data.length; i++) {
            bytes2 b = bytes2(uint16(uint8(data[i])));
            bytes1 hi = bytes1(uint8(uint16(b)) / 16);
            bytes1 lo = bytes1(uint8(uint16(b)) % 16);

            hexString[2 * i] = char(hi);
            hexString[2 * i + 1] = char(lo);
        }

        return string(hexString);
    }

    function bytes32ToHexString(
        bytes32 data
    ) public pure returns (string memory) {
        bytes memory hexString = new bytes(2 * data.length);

        for (uint256 i = 0; i < data.length; i++) {
            bytes2 b = bytes2(uint16(uint8(data[i])));
            bytes1 hi = bytes1(uint8(uint16(b)) / 16);
            bytes1 lo = bytes1(uint8(uint16(b)) % 16);

            hexString[2 * i] = char(hi);
            hexString[2 * i + 1] = char(lo);
        }

        return string(hexString);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) {
            return bytes1(uint8(b) + 0x30);
        } else {
            return bytes1(uint8(b) + 0x57);
        }
    }
}

contract ZKBobSequencer is
    AbstractZkBobPoolSequencerTest,
    AbstractPolygonForkTest
{
    constructor() {
        D = 1;
        token = address(0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B);
        // weth = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
        // tempToken = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        poolType = PoolType.BOB;
        // autoApproveQueue = false;
        permitType = PermitType.BOBPermit;
        denominator = 1_000_000_000;
        precision = 1_000_000_000;
    }
}
