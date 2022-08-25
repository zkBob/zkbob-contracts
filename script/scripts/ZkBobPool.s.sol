// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPool.sol";
import "../../src/zkbob/manager/MutableOperatorManager.sol";

contract DeployZkBobPool is Script {
    function run() external {
        vm.startBroadcast();

        ITransferVerifier transferVerifier;
        ITreeVerifier treeVerifier;
        bytes memory code1 =
            vm.getCode(string.concat("out/", zkBobVerifiers, "/TransferVerifier.sol/TransferVerifier.json"));
        bytes memory code2 =
            vm.getCode(string.concat("out/", zkBobVerifiers, "/TreeUpdateVerifier.sol/TreeUpdateVerifier.json"));
        assembly {
            transferVerifier := create(0, add(code1, 0x20), mload(code1))
            treeVerifier := create(0, add(code2, 0x20), mload(code2))
        }

        ZkBobPool impl = new ZkBobPool(
            0,
            bobVanityAddr,
            transferVerifier,
            treeVerifier
        );
        EIP1967Proxy proxy = new EIP1967Proxy(tx.origin, address(impl), abi.encodeWithSelector(
            ZkBobPool.initialize.selector, zkBobInitialRoot,
            zkBobPoolCap, zkBobDailyDepositCap, zkBobDailyWithdrawalCap, zkBobDailyUserDepositCap, zkBobDepositCap
        ));
        ZkBobPool pool = ZkBobPool(address(proxy));

        IOperatorManager operatorManager = new MutableOperatorManager(zkBobRelayer, zkBobRelayerURL);
        pool.setOperatorManager(operatorManager);

        if (owner != address(0)) {
            pool.transferOwnership(owner);
        }

        if (admin != tx.origin) {
            proxy.setAdmin(admin);
        }

        vm.stopBroadcast();

        require(proxy.implementation() == address(impl), "Invalid implementation address");
        require(proxy.admin() == admin, "Proxy admin is not configured");
        require(pool.owner() == owner, "Owner is not configured");
        require(pool.transfer_verifier() == transferVerifier, "Transfer verifier is not configured");
        require(pool.tree_verifier() == treeVerifier, "Tree verifier is not configured");
    }
}
