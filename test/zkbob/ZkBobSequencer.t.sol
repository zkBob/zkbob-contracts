pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../../src/zkbob/sequencer/ZkBobSequencer.sol";
import "../mocks/TransferVerifierMock.sol";
import "./ZkBobPool.t.sol";

abstract contract AbstractZkBobPoolSequencerTest is
    Test,
    AbstractPolygonForkTest
{
    IZkBobPoolAdmin pool;
    IZkBobDirectDepositsAdmin queue;
    IOperatorManager operatorManager;
    ZkBobAccounting accounting;
    address constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant uniV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant uniV3Quoter = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;

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

    uint256 D;
    address token;
    address weth;
    address tempToken;
    bool autoApproveQueue;
    PoolType poolType;
    PermitType permitType;
    uint256 denominator;
    uint256 precision;
    ZkBobSequencer _sequencer;

    // ZkBobSequencer sequencer = new ZkBobSequencer();

    // assert(op.commitHash == hex"0xdead");

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
        operatorManager = new MutableOperatorManager(
            user2,
            user3,
            "https://example.com"
        );
        pool.setOperatorManager(operatorManager);
        queue.setOperatorManager(operatorManager);
        queue.setDirectDepositFee(uint64(0.1 ether / D));
        queue.setDirectDepositTimeout(1 days);

        deal(token, user1, 1 ether / D);
        deal(token, user3, 0);

        _sequencer = new ZkBobSequencer(address(pool));
    }
}

contract ZKBobSequencer is AbstractZkBobPoolSequencerTest {
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

    function testEmptyQueue() public {
        PriorityOperation memory op = _sequencer.head();

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

        bytes20 proxyAddress = bytes20(msg.sender);

        bytes2 txType = hex"0000";
        bytes8 proxy_fee = hex"0000000000000000";
        bytes8 prover_fee = hex"0000000000000000";

        // New memo struct
        // 0-2 bytes - tx type?
        // 2-22 bytes - proxy address
        // 22-30 bytes - proxy fee
        // 30-38 bytes - prover fee
        memo = bytes.concat(txType,proxyAddress, proxy_fee, prover_fee);
     
        ZkBobSequencer.CommitData memory commitData = ZkBobSequencer.CommitData(
            0,
            0,
            0,
            0,
            memo,
            [uint256(0), 0, 0, 0, 0, 0, 0, 0]
        );

        _sequencer.commit(commitData);
        // PriorityOperation memory op =  PriorityOperation ();
    }
}
