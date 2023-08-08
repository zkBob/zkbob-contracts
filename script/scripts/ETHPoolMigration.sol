// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "forge-std/Vm.sol";
import "./Env.s.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPoolETH.sol";
import "../../src/zkbob/ZkBobPoolETHERC4625Extended.sol";
import "../../src/zkbob/ZkBobDirectDepositQueueETH.sol";
import "../../src/zkbob/ZkBobDirectDepositQueueETHERC4626Extended.sol";
import "../../src/interfaces/IATokenVault.sol";

contract ETHPoolMigration is Script, StdCheats {
    ZkBobPoolETH pool = ZkBobPoolETH(payable(0x58320A55bbc5F89E5D0c92108F762Ac0172C5992));
    ZkBobDirectDepositQueueETH queue_proxy = ZkBobDirectDepositQueueETH(0x318e2C1f5f6Ac4fDD5979E73D498342B255fC869);
    address erc4626token = address(0xac190662aD9b53A4E6D4CD321dbf5d3ECD0E29b0);
    address relayer_addr = address(0x65Eb51b16678d57Bb0bB8d160D1b9D0a57880512);
    address owner = address(0x14fc6a1a996A2EB889cF86e5c8cD17323bC85290);
    address deployer = address(0x39F0bD56c1439a22Ee90b4972c16b7868D161981);

    uint256 fork_block = 107_902_680;

    address withdrawal_recipient = address(0x911Bb65A13AF3f83cd0b60bf113B644b53D7E438);

    function migrate() internal {
        ITransferVerifier transferVerifier = pool.transfer_verifier();
        ITreeVerifier treeVerifier = pool.tree_verifier();
        IBatchDepositVerifier batchDepositVerifier = pool.batch_deposit_verifier();
        uint256 pool_id = pool.pool_id();
        require(queue_proxy == pool.direct_deposit_queue(), "Incorrect Direct Depoist queue proxy");

        vm.startPrank(deployer);
        ZkBobPoolETHERC4625Extended poolImpl = new ZkBobPoolETHERC4625Extended(
            pool_id, erc4626token,
            transferVerifier, treeVerifier, batchDepositVerifier,
            address(queue_proxy), address(0x000000000022D473030F116dDEE9F6B43aC78BA3)
        );
        ZkBobDirectDepositQueueETHERC4626Extended queueImpl =
            new ZkBobDirectDepositQueueETHERC4626Extended(address(pool), erc4626token, pool.denominator());
        vm.stopPrank();

        bytes memory migrationData = abi.encodePacked(poolImpl.migrationToERC4626.selector);

        vm.startPrank(owner);
        EIP1967Proxy(payable(address(pool))).upgradeToAndCall(address(poolImpl), migrationData);
        EIP1967Proxy(payable(address(queue_proxy))).upgradeTo(address(queueImpl));
        vm.stopPrank();
    }

    function makeWithdrawal() internal {
        // tx: 0xa464dc0c59ebb8cd0186f92f42dd2bbc6b41b3156defee47eba9d9011fca13b3
        // hex"0xaf9890831726713583afbd8a215f48c3dc3b203b27d1c7e0e00d378871056e8d101c43f728a5b535d301280b14fed27d373655054b3c3f6b6ebdf60c644be6314dcd4c9200000000b0800000000000000000000000000000ffffffffe538769e1516a6e943f1feb7ef2ae75fcae0a52963aff4a02d54cf0913be5519444d5e7b1e5f7b50968a280bcd31c1498f5af65c785a11cd6f3d09ab16951fd07a086e8c08c1e65d8d24c4a458e7439282a4cc38d209fe0aedecaecb9051bc904a3058862338e45f3685942cdd4fb26266246456d7adf5cb8b323c4b4abc9cf4c6ad8ed802337559c7c420a014683e5ff24967961df4cd472e5cac910fa6f4e3b9163c9919bab545869e708cd48d6d0c8312aac715c7dacf5746df343856bbc3a6d9aa3306546392c896545f0eaa412632a2bb609069e10ecefa364d2da325d0571ca5892327367111aaa2126cd0ad8e6ef12068ed2dc10a951f514cf6c92bea220114441324402c4541dd2e6841ef3b48eaae990c94bfdcee74c344aac824c1c527c6b62f1001cfd3217d4b3e1bb29162a76d0bb63afb60f6aeb0956de9e20a747d7a1218f8a3de879e9349b0ea96afed161683437daf0f0b9f7156597513ddf39ee27d26bcf16189bbe87399737dd02560fb85ac862e38cd333988b23b0dd6d6711d632df0a2987309b5cf3b6b5da89bdea2bb6afa6d82d5329f8b59a633f80c935e0521985d8790b6ae3faad7ce88cc2756aa2c7559433ffb5adf8a7386bac2c3885c28d135cda95d4e2c32a0fb0e816a848b87de4b560719e95be7138078cda6c88b27e39ed9417521ee72e9ab9494241caec75faf81165b6681a4c07d3960d85f822f195ae2e231374f74e612c65a91ddb50cc7988ea923be33dea722f51d86a673000200ee0000000000045722000000001ac33240911bb65a13af3f83cd0b60bf113b644b53d7e43801000000401fec2192f9d8604674ac194e5948650f3923785533ea4c338bda696d5eaf23c545a702dc7b7a75d31bbbf5eb83686052211ee26cb7753f14964d4d04b58425e2929df2d0329a889efc8d365a74e336d14c25c38400340a5b96584d96b2458906882f90db24b7ea88b327bed7b9a77e7ae5e3c2b87ce600a264da69140c4534ae7fcaa3a1f84461f7f4aa4764a890efd1729819df72752b8630b807dde78589025ccdc4093d3eee0eb44581f29b6e12aa43e7efe38cad21d52a08612fe821d09d9abba32fc6"
        vm.startPrank(relayer_addr);
        address(pool).call(
            abi.encodePacked(
                pool.transact.selector,
                hex"1726713583afbd8a215f48c3dc3b203b27d1c7e0e00d378871056e8d101c43f728a5b535d301280b14fed27d373655054b3c3f6b6ebdf60c644be6314dcd4c9200000000b0800000000000000000000000000000ffffffffe538769e1516a6e943f1feb7ef2ae75fcae0a52963aff4a02d54cf0913be5519444d5e7b1e5f7b50968a280bcd31c1498f5af65c785a11cd6f3d09ab16951fd07a086e8c08c1e65d8d24c4a458e7439282a4cc38d209fe0aedecaecb9051bc904a3058862338e45f3685942cdd4fb26266246456d7adf5cb8b323c4b4abc9cf4c6ad8ed802337559c7c420a014683e5ff24967961df4cd472e5cac910fa6f4e3b9163c9919bab545869e708cd48d6d0c8312aac715c7dacf5746df343856bbc3a6d9aa3306546392c896545f0eaa412632a2bb609069e10ecefa364d2da325d0571ca5892327367111aaa2126cd0ad8e6ef12068ed2dc10a951f514cf6c92bea220114441324402c4541dd2e6841ef3b48eaae990c94bfdcee74c344aac824c1c527c6b62f1001cfd3217d4b3e1bb29162a76d0bb63afb60f6aeb0956de9e20a747d7a1218f8a3de879e9349b0ea96afed161683437daf0f0b9f7156597513ddf39ee27d26bcf16189bbe87399737dd02560fb85ac862e38cd333988b23b0dd6d6711d632df0a2987309b5cf3b6b5da89bdea2bb6afa6d82d5329f8b59a633f80c935e0521985d8790b6ae3faad7ce88cc2756aa2c7559433ffb5adf8a7386bac2c3885c28d135cda95d4e2c32a0fb0e816a848b87de4b560719e95be7138078cda6c88b27e39ed9417521ee72e9ab9494241caec75faf81165b6681a4c07d3960d85f822f195ae2e231374f74e612c65a91ddb50cc7988ea923be33dea722f51d86a673000200ee0000000000045722000000001ac33240911bb65a13af3f83cd0b60bf113b644b53d7e43801000000401fec2192f9d8604674ac194e5948650f3923785533ea4c338bda696d5eaf23c545a702dc7b7a75d31bbbf5eb83686052211ee26cb7753f14964d4d04b58425e2929df2d0329a889efc8d365a74e336d14c25c38400340a5b96584d96b2458906882f90db24b7ea88b327bed7b9a77e7ae5e3c2b87ce600a264da69140c4534ae7fcaa3a1f84461f7f4aa4764a890efd1729819df72752b8630b807dde78589025ccdc4093d3eee0eb44581f29b6e12aa43e7efe38cad21d52a08612fe821d09d9abba32fc6"
            )
        );
        vm.stopPrank();
    }

    function depositToVault() internal {
        deal(address(IATokenVault(erc4626token).UNDERLYING()), deployer, 1 ether);
        vm.startPrank(deployer);
        IERC20(IATokenVault(erc4626token).UNDERLYING()).approve(erc4626token, 1 ether);
        IATokenVault(erc4626token).deposit(1 ether, deployer);
        vm.stopPrank();
    }

    function run() external {
        if (block.number != fork_block) {
            return;
        }
        uint256 fork_ts = block.timestamp;

        console2.log("WETH before migration:", IERC20(IATokenVault(erc4626token).UNDERLYING()).balanceOf(address(pool)));
        console2.log("waWETH before migration:", IERC20(erc4626token).balanceOf(address(pool)));
        console2.log("WETH in AAVE before migration:", IATokenVault(erc4626token).previewRedeem(IERC20(erc4626token).balanceOf(address(pool))));

        migrate();

        console2.log("WETH after migration:", IERC20(IATokenVault(erc4626token).UNDERLYING()).balanceOf(address(pool)));
        console2.log("waWETH after migration:", IERC20(erc4626token).balanceOf(address(pool)));
        console2.log("WETH in AAVE after migration:", IATokenVault(erc4626token).previewRedeem(IERC20(erc4626token).balanceOf(address(pool))));

        vm.roll(107_923_679 - fork_block);
        vm.warp(fork_ts + (107_923_679 - fork_block) * 2);

        depositToVault();

        console2.log("WETH in AAVE before withdrawal:", IATokenVault(erc4626token).previewRedeem(IERC20(erc4626token).balanceOf(address(pool))));
        // console2.log("pool before withdrawal:", address(pool).balance);
        console2.log("recipient ETH before withdrawal:", withdrawal_recipient.balance);
        console2.log("recipient WETH before withdrawal:", IERC20(IATokenVault(erc4626token).UNDERLYING()).balanceOf(address(withdrawal_recipient)));

        makeWithdrawal();

        console2.log("WETH after withdrawal:", IERC20(IATokenVault(erc4626token).UNDERLYING()).balanceOf(address(pool)));
        console2.log("waWETH after withdrawal:", IERC20(erc4626token).balanceOf(address(pool)));
        console2.log("WETH in AAVE after withdrawal:", IATokenVault(erc4626token).previewRedeem(IERC20(erc4626token).balanceOf(address(pool))));

        // console2.log("pool after withdrawal:", address(pool).balance);
        console2.log("recipient after withdrawal:", withdrawal_recipient.balance);
        console2.log("recipient WETH before withdrawal:", IERC20(IATokenVault(erc4626token).UNDERLYING()).balanceOf(address(withdrawal_recipient)));
    }
}
