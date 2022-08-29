// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../test/shared/EIP2470.t.sol";
import "../../src/BobToken.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/MultiMinter.sol";
import "../../src/zkbob/ZkBobPool.sol";
import "../../src/zkbob/manager/MutableOperatorManager.sol";

contract DeployLocal is Script {
    function run() external {
        vm.startBroadcast();

        EIP1967Proxy bobProxy = new EIP1967Proxy(tx.origin, mockImpl, "");
        BobToken bobImpl = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(bobImpl));
        BobToken bob = BobToken(address(bobProxy));

        MultiMinter minter = new MultiMinter(address(bob));
        bob.setMinter(address(minter));
        if (bobMinter != address(0)) {
            minter.setMinter(bobMinter, true);
        }

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

        ZkBobPool poolImpl = new ZkBobPool(
            0,
            bobVanityAddr,
            transferVerifier,
            treeVerifier
        );
        EIP1967Proxy poolProxy = new EIP1967Proxy(tx.origin, address(poolImpl), abi.encodeWithSelector(
                ZkBobPool.initialize.selector, zkBobInitialRoot,
                zkBobPoolCap, zkBobDailyDepositCap, zkBobDailyWithdrawalCap, zkBobDailyUserDepositCap, zkBobDepositCap
            ));
        ZkBobPool pool = ZkBobPool(address(poolProxy));

        IOperatorManager operatorManager = new MutableOperatorManager(zkBobRelayer, zkBobRelayerFeeReceiver, zkBobRelayerURL);
        pool.setOperatorManager(operatorManager);

        if (owner != address(0)) {
            bob.transferOwnership(owner);
            minter.transferOwnership(owner);
            pool.transferOwnership(owner);
        }

        if (admin != tx.origin) {
            bobProxy.setAdmin(admin);
            poolProxy.setAdmin(admin);
        }

        vm.stopBroadcast();

        require(bobProxy.implementation() == address(bobImpl), "Invalid implementation address");
        require(bobProxy.admin() == admin, "Proxy admin is not configured");
        require(bob.owner() == owner, "Owner is not configured");
        require(bob.minter() == address(minter), "Minter is not configured");
        require(minter.owner() == owner, "Minter owner is not configured");
        require(bobMinter == address(0) || minter.minter(bobMinter), "Bob minter is not configured");
        require(poolProxy.implementation() == address(poolImpl), "Invalid implementation address");
        require(poolProxy.admin() == admin, "Proxy admin is not configured");
        require(pool.owner() == owner, "Owner is not configured");
        require(pool.transfer_verifier() == transferVerifier, "Transfer verifier is not configured");
        require(pool.tree_verifier() == treeVerifier, "Tree verifier is not configured");

        console2.log("BobToken:", address(bob));
        console2.log("BobToken implementation:", address(bobImpl));
        console2.log("MultiMinter:", address(minter));
        console2.log("ZkBobPool:", address(pool));
        console2.log("ZkBobPool implementation:", address(poolImpl));
    }
}
