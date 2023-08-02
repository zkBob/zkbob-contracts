// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobDirectDepositQueue.sol";
import "../../src/zkbob/ZkBobDirectDepositQueueETH.sol";
import "../../src/zkbob/manager/MutableOperatorManager.sol";
import "../../src/zkbob/ZkBobPoolBOB.sol";
import "../../src/zkbob/ZkBobPoolETH.sol";
import "../../src/zkbob/ZkBobPoolUSDC.sol";
import "../../src/zkbob/ZkBobPoolERC20.sol";

contract DeployZkBobPool is Script {
    function run() external {
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

        EIP1967Proxy poolProxy = new EIP1967Proxy(tx.origin, mockImpl, "");
        EIP1967Proxy queueProxy = new EIP1967Proxy(tx.origin, mockImpl, "");

        ZkBobPool poolImpl;
        if (zkBobPoolType == PoolType.ETH) {
            poolImpl = new ZkBobPoolETH(
                zkBobPoolId, zkBobToken,
                transferVerifier, treeVerifier, batchDepositVerifier,
                address(queueProxy), permit2
            );
        } else if (zkBobPoolType == PoolType.BOB) {
            poolImpl = new ZkBobPoolBOB(
                zkBobPoolId, zkBobToken,
                transferVerifier, treeVerifier, batchDepositVerifier,
                address(queueProxy)
            );
        } else if (zkBobPoolType == PoolType.USDC) {
            poolImpl = new ZkBobPoolUSDC(
                zkBobPoolId, zkBobToken,
                transferVerifier, treeVerifier, batchDepositVerifier,
                address(queueProxy)
            );
        } else if (zkBobPoolType == PoolType.ERC20) {
            uint8 decimals = IERC20Metadata(zkBobToken).decimals();
            uint256 denominator = decimals > 9 ? 10 ** (decimals - 9) : 1;
            uint256 precision = decimals > 9 ? 1_000_000_000 : 10 ** decimals;
            poolImpl = new ZkBobPoolERC20(
                zkBobPoolId, zkBobToken,
                transferVerifier, treeVerifier, batchDepositVerifier,
                address(queueProxy), permit2,
                denominator, precision
            );
        } else {
            revert("Unknown pool type");
        }

        bytes memory initData = abi.encodeWithSelector(
            ZkBobPool.initialize.selector,
            zkBobInitialRoot,
            zkBobPoolCap,
            zkBobDailyDepositCap,
            zkBobDailyWithdrawalCap,
            zkBobDailyUserDepositCap,
            zkBobDepositCap,
            zkBobDailyUserDirectDepositCap,
            zkBobDirectDepositCap
        );
        poolProxy.upgradeToAndCall(address(poolImpl), initData);
        ZkBobPool pool = ZkBobPool(address(poolProxy));

        ZkBobDirectDepositQueue queueImpl;
        if (zkBobPoolType == PoolType.ETH) {
            queueImpl = new ZkBobDirectDepositQueueETH(address(pool), zkBobToken, pool.denominator());
        } else {
            queueImpl = new ZkBobDirectDepositQueue(address(pool), zkBobToken, pool.denominator());
        }
        queueProxy.upgradeTo(address(queueImpl));
        ZkBobDirectDepositQueue queue = ZkBobDirectDepositQueue(address(queueProxy));

        IOperatorManager operatorManager =
            new MutableOperatorManager(zkBobRelayer, zkBobRelayerFeeReceiver, zkBobRelayerURL);
        pool.setOperatorManager(operatorManager);
        queue.setOperatorManager(operatorManager);
        queue.setDirectDepositFee(uint64(zkBobDirectDepositFee));
        queue.setDirectDepositTimeout(uint40(zkBobDirectDepositTimeout));

        if (owner != address(0)) {
            pool.transferOwnership(owner);
            queue.transferOwnership(owner);
        }

        if (admin != tx.origin) {
            poolProxy.setAdmin(admin);
            queueProxy.setAdmin(admin);
        }

        vm.stopBroadcast();

        require(poolProxy.implementation() == address(poolImpl), "Invalid implementation address");
        require(poolProxy.admin() == admin, "Proxy admin is not configured");
        require(pool.owner() == owner, "Owner is not configured");
        require(queueProxy.implementation() == address(queueImpl), "Invalid implementation address");
        require(queueProxy.admin() == admin, "Proxy admin is not configured");
        require(queue.owner() == owner, "Owner is not configured");
        require(pool.transfer_verifier() == transferVerifier, "Transfer verifier is not configured");
        require(pool.tree_verifier() == treeVerifier, "Tree verifier is not configured");
        require(pool.batch_deposit_verifier() == batchDepositVerifier, "Batch deposit verifier is not configured");

        console2.log("ZkBobPool:", address(pool));
        console2.log("ZkBobPool implementation:", address(poolImpl));
        console2.log("ZkBobDirectDepositQueue:", address(queue));
        console2.log("ZkBobDirectDepositQueue implementation:", address(queueImpl));
        console2.log("TransferVerifier:", address(transferVerifier));
        console2.log("TreeUpdateVerifier:", address(treeVerifier));
        console2.log("BatchDepositVierifier:", address(batchDepositVerifier));
    }
}
