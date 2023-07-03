// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPoolBOB.sol";
import "../../src/zkbob/ZkBobPoolUSDC.sol";

contract BOBPoolMigration is Script {
    function run() external {
        ZkBobPoolBOB pool = ZkBobPoolBOB(0x72e6B59D4a90ab232e55D4BB7ed2dD17494D62fB);
        address bob_addr = address(0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B);
        address usdc_addr = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        address relayer_addr = address(0xc2c4AD59B78F4A0aFD0CDB8133E640Db08Fa5b90);
        
        // State before migration
        uint256 snapshot = vm.snapshot();

        uint256 prev_bob_balance = IERC20(bob_addr).balanceOf(relayer_addr);
        vm.startPrank(relayer_addr);
        pool.withdrawFee(relayer_addr, relayer_addr);
        vm.stopPrank();
        uint256 prev_fees = IERC20(bob_addr).balanceOf(relayer_addr) - prev_bob_balance;

        vm.revertTo(snapshot);
        // =====

        ITransferVerifier transferVerifier = pool.transfer_verifier();
        ITreeVerifier treeVerifier = pool.tree_verifier();
        IBatchDepositVerifier batchDepositVerifier = pool.batch_deposit_verifier();
        uint256 pool_id = pool.pool_id();
        IZkBobDirectDepositQueue queue_proxy = pool.direct_deposit_queue();

        vm.startPrank(deployer);
        ZkBobPoolUSDC poolImpl = new ZkBobPoolUSDC(
            pool_id, usdc_addr,
            transferVerifier, treeVerifier, batchDepositVerifier,
            address(queue_proxy)
        );
        vm.stopPrank();

        bytes memory migrationData = abi.encodePacked(poolImpl.migrationToUSDC.selector);

        vm.startPrank(owner);
        IERC20(usdc_addr).approve(address(pool), type(uint256).max);
        EIP1967Proxy(payable(address(pool))).upgradeToAndCall(address(poolImpl), migrationData);
        IERC20(usdc_addr).approve(address(pool), 0);
        vm.stopPrank();

        uint256 prev_usdc_balance = IERC20(usdc_addr).balanceOf(relayer_addr);
        vm.startPrank(relayer_addr);
        pool.withdrawFee(relayer_addr, relayer_addr);
        vm.stopPrank();
        uint256 fees = IERC20(usdc_addr).balanceOf(relayer_addr) - prev_usdc_balance;
        require(fees == prev_fees / (10 ** (IERC20Metadata(bob_addr).decimals() - IERC20Metadata(usdc_addr).decimals())), "Fees does not match");
    }
}
