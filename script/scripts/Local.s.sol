// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../test/shared/EIP2470.t.sol";
import "../../src/BobToken.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPoolBOB.sol";
import "../../src/zkbob/manager/MutableOperatorManager.sol";
import "../../src/zkbob/ZkBobDirectDepositQueue.sol";
import "../../src/zkbob/utils/ZkBobAccounting.sol";

contract DeployLocal is Script {
    function run() external {
        vm.startBroadcast();

        EIP1967Proxy bobProxy = new EIP1967Proxy(tx.origin, mockImpl, "");
        BobToken bobImpl = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(bobImpl));
        BobToken bob = BobToken(address(bobProxy));

        if (bobMinter != address(0)) {
            bob.updateMinter(bobMinter, true, true);
        }

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

        ZkBobPoolBOB poolImpl = new ZkBobPoolBOB(
            zkBobPoolId,
            address(bob),
            transferVerifier,
            treeVerifier,
            batchDepositVerifier,
            address(queueProxy)
        );
        {
            bytes memory initData = abi.encodeWithSelector(ZkBobPool.initialize.selector, zkBobInitialRoot);
            poolProxy.upgradeToAndCall(address(poolImpl), initData);
        }
        ZkBobPoolBOB pool = ZkBobPoolBOB(address(poolProxy));

        ZkBobDirectDepositQueue queueImpl = new ZkBobDirectDepositQueue(address(pool), address(bob), 1_000_000_000);
        queueProxy.upgradeTo(address(queueImpl));
        ZkBobDirectDepositQueue queue = ZkBobDirectDepositQueue(address(queueProxy));

        {
            ZkBobAccounting accounting = new ZkBobAccounting(address(pool), 1_000_000_000);
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
        }

        {
            IOperatorManager operatorManager =
                new MutableOperatorManager(zkBobRelayer, zkBobRelayerFeeReceiver, zkBobRelayerURL);
            pool.setOperatorManager(operatorManager);
            queue.setOperatorManager(operatorManager);
            queue.setDirectDepositFee(uint64(zkBobDirectDepositFee));
            queue.setDirectDepositTimeout(uint40(zkBobDirectDepositTimeout));
        }

        {
            if (owner != address(0)) {
                bob.transferOwnership(owner);
                pool.transferOwnership(owner);
                queue.transferOwnership(owner);
            }

            if (admin != tx.origin) {
                bobProxy.setAdmin(admin);
                poolProxy.setAdmin(admin);
                queueProxy.setAdmin(admin);
            }
        }

        vm.stopBroadcast();

        require(bobProxy.implementation() == address(bobImpl), "Invalid implementation address");
        require(bobProxy.admin() == admin, "Proxy admin is not configured");
        require(bob.owner() == owner, "Owner is not configured");
        require(bobMinter == address(0) || bob.isMinter(bobMinter), "Bob minter is not configured");
        require(poolProxy.implementation() == address(poolImpl), "Invalid implementation address");
        require(poolProxy.admin() == admin, "Proxy admin is not configured");
        require(pool.owner() == owner, "Owner is not configured");
        require(pool.transfer_verifier() == transferVerifier, "Transfer verifier is not configured");
        require(pool.tree_verifier() == treeVerifier, "Tree verifier is not configured");

        console2.log("BobToken:", address(bob));
        console2.log("BobToken implementation:", address(bobImpl));
        console2.log("ZkBobPool:", address(pool));
        console2.log("ZkBobPool implementation:", address(poolImpl));
        console2.log("ZkBobDirectDepositQueue:", address(queue));
        console2.log("ZkBobDirectDepositQueue implementation:", address(queueImpl));
    }
}
