// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./DecentralizedEnv.s.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobDirectDepositQueue.sol";
import "../../src/zkbob/ZkBobDirectDepositQueueETH.sol";
import "../../src/zkbob/manager/AllowListOperatorManager.sol";
import "../../src/zkbob/ZkBobPoolBOB.sol";
import "../../src/zkbob/ZkBobPoolETH.sol";
import "../../src/zkbob/ZkBobPoolUSDC.sol";
import "../../src/zkbob/ZkBobPoolERC20.sol";
import "../../src/zkbob/utils/ZkBobAccounting.sol";

contract DeployZkBobPool is Script {
    struct Vars {
        uint8 decimals;
        uint256 denominator;
        uint256 precision;
        EIP1967Proxy poolProxy;
        EIP1967Proxy queueProxy;
        ZkBobPool poolImpl;
    }

    function run() external {
        Vars memory vars;
        vars.decimals = IERC20Metadata(zkBobToken).decimals();
        vars.denominator = vars.decimals > 9 ? 10 ** (vars.decimals - 9) : 1;
        vars.precision = vars.decimals > 9 ? 1_000_000_000 : 10 ** vars.decimals;

        vm.startBroadcast();

        ITransferVerifier transferVerifier;
        ITreeVerifier treeVerifier;
        IBatchDepositVerifier batchDepositVerifier;
        bytes memory code1 =
            vm.getCode(string.concat("out/", zkBobVerifiers, "/TransferVerifier.sol/TransferVerifier.json"));
        bytes memory code2 =
            vm.getCode(string.concat("out/", zkBobVerifiers, "/TreeUpdateVerifier.sol/TreeUpdateVerifier.json"));
        bytes memory code3 = vm.getCode(
            string.concat("out/", zkBobVerifiers, "/DelegatedDepositVerifier.sol/DelegatedDepositVerifier.json")
        );
        assembly {
            transferVerifier := create(0, add(code1, 0x20), mload(code1))
            treeVerifier := create(0, add(code2, 0x20), mload(code2))
            batchDepositVerifier := create(0, add(code3, 0x20), mload(code3))
        }

        vars.poolProxy = new EIP1967Proxy(tx.origin, mockImpl, "");
        vars.queueProxy = new EIP1967Proxy(tx.origin, mockImpl, "");

        if (zkBobPoolType == PoolType.ETH) {
            vars.poolImpl = new ZkBobPoolETH(
                zkBobPoolId,
                zkBobToken,
                transferVerifier,
                treeVerifier,
                batchDepositVerifier,
                address(vars.queueProxy),
                permit2
            );
        } else if (zkBobPoolType == PoolType.BOB) {
            vars.poolImpl = new ZkBobPoolBOB(
                zkBobPoolId, zkBobToken, transferVerifier, treeVerifier, batchDepositVerifier, address(vars.queueProxy)
            );
        } else if (zkBobPoolType == PoolType.USDC) {
            vars.poolImpl = new ZkBobPoolUSDC(
                zkBobPoolId, zkBobToken, transferVerifier, treeVerifier, batchDepositVerifier, address(vars.queueProxy)
            );
        } else if (zkBobPoolType == PoolType.ERC20) {
            vars.poolImpl = new ZkBobPoolERC20(
                zkBobPoolId,
                zkBobToken,
                transferVerifier,
                treeVerifier,
                batchDepositVerifier,
                address(vars.queueProxy),
                permit2,
                vars.denominator
            );
        } else {
            revert("Unknown pool type");
        }

        bytes memory initData = abi.encodeWithSelector(ZkBobPool.initialize.selector, zkBobInitialRoot);
        vars.poolProxy.upgradeToAndCall(address(vars.poolImpl), initData);
        ZkBobPool pool = ZkBobPool(address(vars.poolProxy));

        ZkBobDirectDepositQueue queueImpl;
        if (zkBobPoolType == PoolType.ETH) {
            queueImpl = new ZkBobDirectDepositQueueETH(address(pool), zkBobToken, vars.denominator);
        } else {
            queueImpl = new ZkBobDirectDepositQueue(address(pool), zkBobToken, vars.denominator);
        }
        vars.queueProxy.upgradeTo(address(queueImpl));
        ZkBobDirectDepositQueue queue = ZkBobDirectDepositQueue(address(vars.queueProxy));

        // Deploy and set operator manager
        {
            address[] memory operators = new address[](2);
            operators[0] = zkBobRelayer1;
            operators[1] = zkBobRelayer2;

            address[] memory feeReceivers = new address[](2);
            feeReceivers[0] = zkBobRelayerFeeReceiver1;
            feeReceivers[1] = zkBobRelayerFeeReceiver2;

            IOperatorManager operatorManager = new AllowListOperatorManager(operators, feeReceivers, true);
            pool.setOperatorManager(operatorManager);
            queue.setOperatorManager(operatorManager);
        }
        
        queue.setDirectDepositFee(uint64(zkBobDirectDepositFee));
        queue.setDirectDepositTimeout(uint40(zkBobDirectDepositTimeout));

        ZkBobAccounting accounting = new ZkBobAccounting(address(pool), vars.precision);
        accounting.setLimits(
            0,
            zkBobPoolCap,
            zkBobDailyDepositCap,
            zkBobDailyWithdrawalCap,
            zkBobDailyUserDepositCap,
            zkBobDepositCap,
            zkBobDailyUserDirectDepositCap,
            zkBobDirectDepositCap
        );
        pool.setAccounting(accounting);

        pool.setGracePeriod(gracePeriod);
        pool.setMinTreeUpdateFee(minTreeUpdateFee);

        if (owner != address(0)) {
            pool.transferOwnership(owner);
            queue.transferOwnership(owner);
        }

        if (admin != tx.origin) {
            vars.poolProxy.setAdmin(admin);
            vars.queueProxy.setAdmin(admin);
        }

        vm.stopBroadcast();

        require(vars.poolProxy.implementation() == address(vars.poolImpl), "Invalid implementation address");
        require(vars.poolProxy.admin() == admin, "Proxy admin is not configured");
        require(pool.owner() == owner, "Owner is not configured");
        require(vars.queueProxy.implementation() == address(queueImpl), "Invalid implementation address");
        require(vars.queueProxy.admin() == admin, "Proxy admin is not configured");
        require(queue.owner() == owner, "Owner is not configured");
        require(pool.transfer_verifier() == transferVerifier, "Transfer verifier is not configured");
        require(pool.tree_verifier() == treeVerifier, "Tree verifier is not configured");
        require(pool.batch_deposit_verifier() == batchDepositVerifier, "Batch deposit verifier is not configured");

        console2.log("ZkBobPool:", address(pool));
        console2.log("ZkBobPool implementation:", address(vars.poolImpl));
        console2.log("ZkBobDirectDepositQueue:", address(queue));
        console2.log("ZkBobDirectDepositQueue implementation:", address(queueImpl));
        console2.log("ZkBobAccounting:", address(accounting));
        console2.log("TransferVerifier:", address(transferVerifier));
        console2.log("TreeUpdateVerifier:", address(treeVerifier));
        console2.log("BatchDepositVierifier:", address(batchDepositVerifier));
    }
}
