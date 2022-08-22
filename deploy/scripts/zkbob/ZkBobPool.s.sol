// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "../../../src/proxy/EIP1967Proxy.sol";
import "../../../src/zkbob/ZkBobPool.sol";
import "../../../src/zkbob/manager/MutableOperatorManager.sol";

contract DeployZkBobPool is Script {
    address private constant admin = 0xBF3d6f830CE263CAE987193982192Cd990442B53;
    address private constant owner = 0xBF3d6f830CE263CAE987193982192Cd990442B53;
    address private constant token = 0xB0B65813DD450B7c98Fed97404fAbAe179A00B0B;
    address private constant relayer = 0xBA6f711e1D4dB0CBfbC09D1d11C5Fb7445160673;
    string private constant relayerURL = "https://example.com";

    address private constant mockImpl = address(0xdead);

    uint256 private constant initialRoot = 11469701942666298368112882412133877458305516134926649826543144744382391691533;

    function run() external {
        vm.startBroadcast();

        ITransferVerifier transferVerifier;
        ITreeVerifier treeVerifier;
        bytes memory code1 = vm.getCode("out/stage/TransferVerifier.sol/TransferVerifier.json");
        bytes memory code2 = vm.getCode("out/stage/TreeUpdateVerifier.sol/TreeUpdateVerifier.json");
        assembly {
            transferVerifier := create(0, add(code1, 0x20), mload(code1))
            treeVerifier := create(0, add(code2, 0x20), mload(code2))
        }

        EIP1967Proxy proxy = new EIP1967Proxy(tx.origin, mockImpl);

        ZkBobPool impl = new ZkBobPool(
            1,
            token,
            1e9,
            transferVerifier,
            treeVerifier
        );

        proxy.upgradeToAndCall(address(impl), abi.encodeWithSelector(ZkBobPool.initialize.selector, initialRoot));
        ZkBobPool pool = ZkBobPool(address(proxy));

        IOperatorManager operatorManager = new MutableOperatorManager(relayer, relayerURL);
        pool.setOperatorManager(operatorManager);

        if (owner != address(0)) {
            pool.transferOwnership(owner);
        }

        if (admin != address(0) && tx.origin != admin) {
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
