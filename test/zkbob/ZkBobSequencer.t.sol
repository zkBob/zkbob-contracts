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
import "../shared/Env.t.sol";

import "forge-std/console2.sol";

abstract contract AbstractZkBobPoolSequencerTest is AbstractForkTest {
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

        deal(token, user1, 1 ether / D);
        deal(token, user2, 1 ether / D);
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

        vm.prank(user1);
        IERC20(token).approve(address(pool), (uint256(amount) + proxyFee + proverFee) * 1_000_000_000);

        hoax(prover1);
        (bool success, )  = address(sequencer).call(abi.encodePacked(ZkBobSequencer.commit.selector, commitData));
        assertTrue(success);

        vm.warp(block.timestamp + sequencer.PROXY_GRACE_PERIOD() + 1);


        uint256 prover1FeeBefore = sequencer.accumulatedFees(prover1);
        uint256 prover2FeeBefore = sequencer.accumulatedFees(prover2);
        hoax(prover2);    
        (success, )  = address(sequencer).call(abi.encodePacked(ZkBobSequencer.prove.selector, proveData));
        uint256 prover1FeeAfter = sequencer.accumulatedFees(prover1);
        uint256 prover2FeeAfter = sequencer.accumulatedFees(prover2);

        assertTrue(success);
        assertTrue(prover1FeeAfter == prover1FeeBefore + proxyFee);
        assertTrue(prover2FeeAfter == prover2FeeBefore + proverFee);
    }

    function testCanSkipExpiredOperation() external {
        int256 amount = int256(3);
        uint64 proxyFee = uint64(1);
        uint64 proverFee = uint64(2);
        (bytes memory firstCommitData, bytes memory firstProveData) = _encodeDeposit(amount, proxyFee, proverFee, prover1);
        (bytes memory secondCommitData, bytes memory secondProveData) = _encodeDeposit(amount, proxyFee, proverFee, prover2);
        
        vm.prank(user1);
        IERC20(token).approve(address(pool), (uint256(amount) + proxyFee + proverFee) * 1_000_000_000);
        
        hoax(prover1);
        (bool success, )  = address(sequencer).call(abi.encodePacked(ZkBobSequencer.commit.selector, firstCommitData));
        assertTrue(success);

        hoax(prover2);    
        (success, )  = address(sequencer).call(abi.encodePacked(ZkBobSequencer.commit.selector, secondCommitData));
        assertTrue(success);

        vm.warp(block.timestamp + sequencer.EXPIRATION_TIME() + 1);

        uint256 prover1FeeBefore = sequencer.accumulatedFees(prover1);
        uint256 prover2FeeBefore = sequencer.accumulatedFees(prover2);

        hoax(prover1);
        (success, )  = address(sequencer).call(abi.encodePacked(ZkBobSequencer.prove.selector, firstProveData));
        assertFalse(success);

        hoax(prover2);    
        (success, )  = address(sequencer).call(abi.encodePacked(ZkBobSequencer.prove.selector, secondProveData));
        assertTrue(success);

        uint256 prover1FeeAfter = sequencer.accumulatedFees(prover1);
        uint256 prover2FeeAfter = sequencer.accumulatedFees(prover2);

        assertTrue(prover1FeeAfter == prover1FeeBefore);
        assertTrue(prover2FeeAfter == prover2FeeBefore + proxyFee + proverFee);
    }

    function testCanWithdrawFees() external {
        deposit(int256(1), uint64(12), uint64(27), prover1);
        deposit(int256(1), uint64(3), uint64(7), prover2);

        uint256 prover1FeeBefore = sequencer.accumulatedFees(prover1);
        uint256 prover1BalanceBefore = IERC20(token).balanceOf(prover1);
        uint256 prover2FeeBefore = sequencer.accumulatedFees(prover2);
        uint256 prover2BalanceBefore = IERC20(token).balanceOf(prover2);

        assertTrue(prover1FeeBefore == uint64(39));
        assertTrue(prover2FeeBefore == uint64(10));
        
        hoax(prover1);
        sequencer.withdrawFees();

        hoax(prover2);
        sequencer.withdrawFees();

        uint256 prover1FeeAfter = sequencer.accumulatedFees(prover1);
        uint256 prover1BalanceAfter = IERC20(token).balanceOf(prover1);
        uint256 prover2FeeAfter = sequencer.accumulatedFees(prover2);
        uint256 prover2BalanceAfter = IERC20(token).balanceOf(prover2);

        assertTrue(prover1FeeAfter == 0);
        assertTrue(prover1BalanceAfter == prover1BalanceBefore + prover1FeeBefore * denominator);

        assertTrue(prover2FeeAfter == 0);
        assertTrue(prover2BalanceAfter == prover2BalanceBefore + prover2FeeBefore * denominator);
    }

    function testPermitDepositCommit() external {
        uint256 amount = uint256(38);
        uint64 proxyFee = uint64(66);
        uint64 proverFee = uint64(77);

        (bytes memory commitData, ) = _encodePermitDeposit(
            amount,
            user1,
            proxyFee,
            proverFee
        );

        vm.prank(user1);

        (bool success, ) = address(sequencer).call(
            (abi.encodePacked(ZkBobSequencer.commit.selector, commitData))
        );

        assertTrue(success);
    }

    function deposit(int256 amount, uint64 proxyFee, uint64 proverFee, address prover) internal {
        (bytes memory commitData, bytes memory proveData) = _encodeDeposit(amount, proxyFee, proverFee, prover);
        
        vm.prank(user1);
        IERC20(token).approve(address(pool), (uint256(amount) + proxyFee + proverFee) * denominator);
        
        startHoax(prover);
        (bool success, ) = address(sequencer).call(abi.encodePacked(ZkBobSequencer.commit.selector, commitData));
        assertTrue(success);

        uint256 feeBefore = sequencer.accumulatedFees(prover);
        (success, ) = address(sequencer).call(abi.encodePacked(ZkBobSequencer.prove.selector, proveData));
        uint256 feeAfter = sequencer.accumulatedFees(prover);
        
        assertTrue(success);
        assertTrue(feeAfter == feeBefore + proxyFee + proverFee);

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
        (uint8 vProver, bytes32 rProver, bytes32 sProver) = vm.sign(
            pk1,
            proxyDigest
        );
        (uint8 vProxy, bytes32 rProxy, bytes32 sProxy) = vm.sign(
            pk1,
            proverDigest
        );

        return
            abi.encodePacked(
                data,
                _encodePermitSignature(vProxy, rProxy, sProxy), //64
                _encodePermitSignature(vProver, rProver, sProver) //64
            );
    }

    function _encodePermitSignature(
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(uint256(s) + (v == 28 ? (1 << 255) : 0));
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
        bytes32 nullifier = bytes32(_randFR());

        bytes32 proverPermitDigest;
        bytes32 proxyPermitDigest;
        if (permitType == PermitType.BOBPermit) {
            proxyPermitDigest = _digestSaltedPermit(
                user1,
                address(sequencer),
                _proxyFee,
                expiry,
                nullifier
            );
            proverPermitDigest = _digestSaltedPermit(
                user1,
                address(pool),
                uint256(_amount + uint256(_proverFee)),
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
            uint112(4269), //energy 14
            uint64(_amount / uint256(denominator)) //token amount 8
        );
        for (uint256 i = 0; i < 8; i++) {
            commitData = abi.encodePacked(commitData, new bytes(32)); //tx proof(8)*32 = 256
        }

        proveData = commitData;

        for (uint256 i = 0; i < 8; i++) {
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

        console2.log("commitData1", bytesToHexString(commitData));

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

    function _randFR() internal view returns (uint256) {
        return
            uint256(keccak256(abi.encode(gasleft()))) %
            21888242871839275222246405745257275088696311157297823662689037894645226208583;
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
