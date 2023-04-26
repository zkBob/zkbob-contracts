// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobDirectDepositQueueETH.sol";
import "../../src/zkbob/manager/MutableOperatorManager.sol";
import "../../src/zkbob/ZkBobPoolETH.sol";

contract DeployZkBobPoolETH is Script {
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

        ZkBobPoolETH poolImpl = new ZkBobPoolETH(
            zkBobPoolId,
            weth,
            transferVerifier,
            treeVerifier,
            batchDepositVerifier,
            address(queueProxy),
            permit2
        );
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
        ZkBobPoolETH pool = ZkBobPoolETH(payable(address(poolProxy)));

        ZkBobDirectDepositQueueETH queueImpl = new ZkBobDirectDepositQueueETH(address(pool), weth, 1_000_000_000);
        queueProxy.upgradeTo(address(queueImpl));
        ZkBobDirectDepositQueueETH queue = ZkBobDirectDepositQueueETH(address(queueProxy));

        IOperatorManager operatorManager =
            new MutableOperatorManager(zkBobRelayer, zkBobRelayerFeeReceiver, zkBobRelayerURL);
        pool.setOperatorManager(operatorManager);
        queue.setOperatorManager(operatorManager);

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
