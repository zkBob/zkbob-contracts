// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {AbstractForkTest, AbstractPolygonForkTest} from "../shared/ForkTests.t.sol";
import {IZkBobDirectDepositsAdmin} from "../interfaces/IZkBobDirectDepositsAdmin.sol";
import {IZkBobPoolAdmin} from "../interfaces/IZkBobPoolAdmin.sol";
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
import "../shared/Env.t.sol";

abstract contract AbstractZkBobPoolSequencerTest is AbstractForkTest {
    address constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
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

    address token;
    PoolType poolType;
    uint256 denominator;
    uint256 precision;
    uint256 D;

    IZkBobPoolAdmin pool;
    IZkBobDirectDepositsAdmin queue;
    ZkBobSequencer sequencer;
    MutableOperatorManager operatorManager;
    ZkBobAccounting accounting;

    function setUp() public {
        vm.createSelectFork(forkRpcUrl, forkBlock);

        EIP1967Proxy poolProxy = new EIP1967Proxy(address(this), address(0xdead), "");
        EIP1967Proxy queueProxy = new EIP1967Proxy(address(this), address(0xdead), "");

        ZkBobPool impl;
        if (poolType == PoolType.ETH) {
            impl = new ZkBobPoolETH(
                0, token,
                new TransferVerifierMock(), new TreeUpdateVerifierMock(), new BatchDepositVerifierMock(),
                address(queueProxy), permit2
            );
        } else if (poolType == PoolType.BOB) {
            impl = new ZkBobPoolBOB(
                0, token,
                new TransferVerifierMock(), new TreeUpdateVerifierMock(), new BatchDepositVerifierMock(),
                address(queueProxy)
            );
        } else if (poolType == PoolType.USDC) {
            impl = new ZkBobPoolUSDC(
                0, token,
                new TransferVerifierMock(), new TreeUpdateVerifierMock(), new BatchDepositVerifierMock(),
                address(queueProxy)
            );
        } else if (poolType == PoolType.ERC20) {
            impl = new ZkBobPoolERC20(
                0, token,
                new TransferVerifierMock(), new TreeUpdateVerifierMock(), new BatchDepositVerifierMock(),
                address(queueProxy), permit2, 1_000_000_000
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
        sequencer = new ZkBobSequencer(address(pool));
        operatorManager = new MutableOperatorManager(address(sequencer), address(sequencer), "https://example.com");
        pool.setOperatorManager(operatorManager);
        queue.setOperatorManager(operatorManager);
        queue.setDirectDepositFee(uint64(0.1 ether / D));
        queue.setDirectDepositTimeout(1 days);

        deal(token, user1, 1 ether / D);
        deal(token, user3, 0);
    }

    function testEmptyQueue() public {
        PriorityOperation memory op = sequencer.head();

        bytes32 commitHash = op.commitHash;

        assertEq(
            commitHash,
            hex"0000000000000000000000000000000000000000000000000000000000000000"
        );
    }

    function testCommit() public {
        //     struct CommitData {
        //     uint48 index;
        //     uint256 out_commit;
        //     uint256 nullifier;
        //     uint256 transfer_delta;
        //     bytes memo;
        //     uint256[8] transfer_proof;
        // }

        bytes memory memo = new bytes(38); //2+8+8+20

        address proxyAddress = user1;

        uint16 txType = 0;
        uint64 proxy_fee = 1;
        uint64 prover_fee = 1;

        // New memo struct
        // 0-2 bytes - tx type?
        // 2-22 bytes - proxy address
        // 22-30 bytes - proxy fee
        // 30-38 bytes - prover fee
        memo = encodeMemo(txType, proxyAddress, proxy_fee, prover_fee);
     
        ZkBobSequencer.CommitData memory commitData = ZkBobSequencer.CommitData(
            0,
            0,
            0,
            0,
            memo,
            [uint256(0), 0, 0, 0, 0, 0, 0, 0]
        );

        vm.startPrank(user1);
        sequencer.commit(commitData);
        vm.stopPrank();
        // PriorityOperation memory op =  PriorityOperation ();
    }

    // TODO:
    function encodeMemo(uint16 memo, address prover, uint64 proxyFee, uint64 proverFee) internal returns (bytes memory) {
        return bytes.concat(bytes2(memo), bytes20(prover), bytes8(proxyFee), bytes8(proverFee));
    }
}

contract ZKBobSequencer is AbstractZkBobPoolSequencerTest, AbstractPolygonForkTest {
    constructor() {
        D = 1;
        token = address(0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B);
        // weth = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
        // tempToken = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        poolType = PoolType.BOB;
        // autoApproveQueue = false;
        // permitType = PermitType.BOBPermit;
        denominator = 1_000_000_000;
        precision = 1_000_000_000;
    }
}
