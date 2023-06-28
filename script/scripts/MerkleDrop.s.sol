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
import "../../src/CumulativeMerkleDrop.sol";
import "../../src/minters/FaucetMinter.sol";

contract DeployLocal is Script {

    function deployTokenAndPool() internal returns (BobToken bob, ZkBobDirectDepositQueue queue) {

        vm.startBroadcast();
        EIP1967Proxy bobProxy = new EIP1967Proxy(tx.origin, mockImpl, "");
        // BobToken bobImpl = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(new BobToken(address(bobProxy))));
        bob = BobToken(address(bobProxy));

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
        }
        ZkBobPoolBOB pool = ZkBobPoolBOB(address(poolProxy));

        // ZkBobDirectDepositQueue queueImpl = new ZkBobDirectDepositQueue(address(pool), address(bob), 1_000_000_000);
        queueProxy.upgradeTo(address(new ZkBobDirectDepositQueue(address(pool), address(bob), 1_000_000_000)));
        queue = ZkBobDirectDepositQueue(address(queueProxy));

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

        // require(bobProxy.implementation() == address(bobImpl), "Invalid implementation address");
        require(bobProxy.admin() == admin, "Proxy admin is not configured");
        require(bob.owner() == owner, "Owner is not configured");
        require(bobMinter == address(0) || bob.isMinter(bobMinter), "Bob minter is not configured");
        require(poolProxy.implementation() == address(poolImpl), "Invalid implementation address");
        require(poolProxy.admin() == admin, "Proxy admin is not configured");
        require(pool.owner() == owner, "Owner is not configured");
        require(pool.transfer_verifier() == transferVerifier, "Transfer verifier is not configured");
        require(pool.tree_verifier() == treeVerifier, "Tree verifier is not configured");

        console2.log("BobToken:", address(bob));
        // console2.log("BobToken implementation:", address(bobImpl));
        console2.log("ZkBobPool:", address(pool));
        console2.log("ZkBobPool implementation:", address(poolImpl));
        console2.log("ZkBobDirectDepositQueue:", address(queue));
        // console2.log("ZkBobDirectDepositQueue implementation:", address(queueImpl));
    }

function hexToBytes32(string memory hexString) public pure returns (bytes32) {
        require(bytes(hexString).length == 64, "Invalid hex string length");

        bytes32 result;
        assembly {
            result := mload(add(hexString, 32))
        }
        return result;
    }
    function claim(CumulativeMerkleDrop merkleDrop) internal {
        bytes32[] memory proofs = new bytes32[] (5);
        proofs[0] = bytes32(0xe0bdf54b5096557245515b1611d9229f4fbaabf63b52826f3495adba95ef7fdc);
        proofs[1] = bytes32(0xfb4e693e4b86e83f39d42398b328e7efa23eda26bfeda87d13f281482ea67013);
        proofs[2] = bytes32(0x5e3c62346ba3ec85ad70afaca843914219224e267ffba11fdb4e7ee73f38b1e6);
        proofs[3] = bytes32(0x1755b5d981cb61f7c5e837a30c49316ce6aeb844db995a24818e197b587b7d3f);
        proofs[4] = bytes32(0x390c6a65785ed05144461985841b4af8f722180265e9dbb7a797941eaa36a7fb);
        
        // "0xe0bdf54b5096557245515b1611d9229f4fbaabf63b52826f3495adba95ef7fdc",
        // "0xfb4e693e4b86e83f39d42398b328e7efa23eda26bfeda87d13f281482ea67013",
        // "0x5e3c62346ba3ec85ad70afaca843914219224e267ffba11fdb4e7ee73f38b1e6",
        // "0x1755b5d981cb61f7c5e837a30c49316ce6aeb844db995a24818e197b587b7d3f",
        // "0x390c6a65785ed05144461985841b4af8f722180265e9dbb7a797941eaa36a7fb"
        merkleDrop.claim(address(msg.sender),0xde0b6b3a7640000, 0x219f15dcc639a8503ec6066dde29ed09fc005832883ec3c2061534249c1224ef, 
        proofs );
    }
    function run() external {
        (BobToken bob, ZkBobDirectDepositQueue queue) = deployTokenAndPool();        

        vm.startBroadcast();

        FaucetMinter faucetMinter = new FaucetMinter(address(bob), 1000 ether);
        
        bob.updateMinter(address(faucetMinter),true, true);

        CumulativeMerkleDrop merkleDrop = new CumulativeMerkleDrop(address(bob), address(queue));

        merkleDrop.setMerkleRoot(bytes32(0x219f15dcc639a8503ec6066dde29ed09fc005832883ec3c2061534249c1224ef));

        faucetMinter.mint(address(merkleDrop), 999 ether);


        vm.stopBroadcast();
        
        console2.log("merkle drop adress", address(merkleDrop));
        console2.log("merkle contract balance", bob.balanceOf(address(merkleDrop)));
        console2.log("caller" , msg.sender);

        vm.startBroadcast();
        claim(merkleDrop);
        vm.stopBroadcast();

    }
}
