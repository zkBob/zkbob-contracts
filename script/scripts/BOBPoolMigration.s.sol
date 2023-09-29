// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "forge-std/Vm.sol";
import "./Env.s.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../src/interfaces/IERC20Permit.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPoolBOB.sol";
import "../../src/zkbob/ZkBobPoolUSDCMigrated.sol";
import "../../src/zkbob/utils/ZkBobAccounting.sol";
import "../../src/zkbob/ZkBobDirectDepositQueue.sol";
import "../../src/utils/UniswapV3Seller.sol";

contract BOBPoolMigration is Script, StdCheats {
    ZkBobPoolBOB pool = ZkBobPoolBOB(0x1CA8C2B9B20E18e86d5b9a72370fC6c91814c97C);
    ZkBobDirectDepositQueue queue_proxy = ZkBobDirectDepositQueue(0x15B8C75c024acba8c114C21F42eb515A762c0014);
    address bob_addr = address(0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B);
    address usdc_addr = address(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85);
    address relayer_addr = address(0xb9CD01c0b417b4e9095f620aE2f849A84a9B1690);

    struct VerificationValues {
        uint256 withdrawalDiff;
        uint256 depositDiff;
        uint256 fees;
        uint256 ddIn;
        uint256 ddOutDiff;
        ZkBobAccounting.Limits limits;
    }

    function migrate() internal {
        ITransferVerifier transferVerifier = pool.transfer_verifier();
        ITreeVerifier treeVerifier = pool.tree_verifier();
        IBatchDepositVerifier batchDepositVerifier = pool.batch_deposit_verifier();
        uint256 pool_id = pool.pool_id();
        require(queue_proxy == pool.direct_deposit_queue(), "Incorrect Direct Depoist queue proxy");

        vm.startPrank(deployer);
        ZkBobPoolUSDCMigrated poolImpl = new ZkBobPoolUSDCMigrated(
            pool_id, usdc_addr,
            transferVerifier, treeVerifier, batchDepositVerifier,
            address(queue_proxy)
        );
        UniswapV3Seller seller =
        new UniswapV3Seller(uniV3Router, uniV3Quoter, usdc_addr, 100, address(0x7F5c764cBc14f9669B88837ca1490cCa17c31607), 500);
        ZkBobDirectDepositQueue queueImpl = new ZkBobDirectDepositQueue(address(pool), usdc_addr, 1);
        vm.stopPrank();

        bytes memory migrationData = abi.encodePacked(poolImpl.migrationToUSDC.selector);

        deal(usdc_addr, address(owner), 1000_000_000);
        vm.startPrank(owner);
        IERC20(usdc_addr).approve(address(pool), type(uint256).max);
        EIP1967Proxy(payable(address(pool))).upgradeToAndCall(address(poolImpl), migrationData);
        IERC20(usdc_addr).approve(address(pool), 0);
        EIP1967Proxy(payable(address(queue_proxy))).upgradeTo(address(queueImpl));
        pool.setTokenSeller(address(seller));
        vm.stopPrank();
    }

    function makeFeesWithdrawal() internal {
        vm.startPrank(relayer_addr);
        pool.withdrawFee(relayer_addr, relayer_addr);
        vm.stopPrank();
    }

    function makeWithdrawal() internal {
        // fork block: 110_198_152
        // tx: 0x4bea90b237e81940be79eb8589b71500f3c6f8b08bca3cdb1500d9a3a0f1ef79
        // hex"1dd6f9921ddaf1ccd3d16f2f662114f22e0d9e9579a583b848943bf1d42779f507789cfaf3b1e9a0e69fabdebc20f13046ed911413a336d0e8a9ff5384788b0d0000000487800000000000000000000000000000fffffffb42730e0012f77d7d40afb199bf5d9c8f62d0fc2869d3fcf313bd73f20e70842addc0e52f1e07cebe0608262f77b8d4e1ca8c64c1ee4726953e32fbbda27a7fe2eb823c281fb76d8e66a4ec9b2257c91fa80df7acef8dae9267a45f0f4d81339940a6d46a238d406c374584026c7a3bbf7475eb1bb543f96f72148c716e498112cb2d60fe2561f65dabc3cf88a032d7819cda0a590953895171a6485aeaf41cdcaa5ba0580317d2226b98295f2cac7e16b5d24d52d9b1e994769e84583e66e50ceac90b782279cf5a5a4ca7de56c99e19a2f5b3e834f34c367ce605c5fa551b5c3dce9b2d0dae21b9a5cfe19b28ae9510085ff4b633865185db5fd9ca997c9bf2ebee73250f955c6a4325cd724f0ce732e6d3058b6e66fbc887fc18ea5fc588729595356022327f8de0dc1a7c6de88500ab5ba19d010d0864fc61a23c23f2fc174f84715b29f20ae261b3c9023e8c2a67c67cbb9192b50d58c3dc8760cbc45dda83f5ca5a2fd440e1740f11903d6fac2c72dec3b7d628b2d22e7efc0986cf36d9eb2d210b17d70dcb495805aa90c1f2f67159f916b0a1ff8f557ef340b006b73afaa5d76b20016f87e7a713ddf2eba6f20620f0f2dc6ece52e6c2f39a4e21e338672f67351396c1959a679f2a6a9e1af777868275be05283b6ca12265aa532c8587f0e7e5188c2968cf9bf0b7f42c00d8ce2e1cd01e586fa60eb0a7114163acec87b320ab292c304decf7034ef68cb38d0a8e9253a181f2138781c2bfc98f7eb22135996c000200ee0000000015752a00000000012a05f20039f0bd56c1439a22ee90b4972c16b7868d16198101000000fa2cce4e0c4c31fefdc7fa89c2c1d1c4663c2d7d1f14aa03e2feeccef437e227658f5f77a35f6afb74a1fd9b29bb1be034ff21eb7696793ad0e7d4a30a4dd30d1963d72a2e98e40d89e3e905424a0a688c67f78e540d0d92477f00c424ab7e0183eb9c40e9223310a224d4cc0fd529699aa9fa76a85323a84ecdad2e635a7e85672a24f09aebf9c2dced55812b4087cd0363b9db256982c52286af541e270dbb3c23bc281cfc4282facf0b1779c7a3adcb7f76983f2e30d50dc7a93951c6ca27723610195122"
        vm.startPrank(relayer_addr);
        address(pool).call(
            abi.encodePacked(
                pool.transact.selector,
                hex"1dd6f9921ddaf1ccd3d16f2f662114f22e0d9e9579a583b848943bf1d42779f507789cfaf3b1e9a0e69fabdebc20f13046ed911413a336d0e8a9ff5384788b0d0000000487800000000000000000000000000000fffffffb42730e0012f77d7d40afb199bf5d9c8f62d0fc2869d3fcf313bd73f20e70842addc0e52f1e07cebe0608262f77b8d4e1ca8c64c1ee4726953e32fbbda27a7fe2eb823c281fb76d8e66a4ec9b2257c91fa80df7acef8dae9267a45f0f4d81339940a6d46a238d406c374584026c7a3bbf7475eb1bb543f96f72148c716e498112cb2d60fe2561f65dabc3cf88a032d7819cda0a590953895171a6485aeaf41cdcaa5ba0580317d2226b98295f2cac7e16b5d24d52d9b1e994769e84583e66e50ceac90b782279cf5a5a4ca7de56c99e19a2f5b3e834f34c367ce605c5fa551b5c3dce9b2d0dae21b9a5cfe19b28ae9510085ff4b633865185db5fd9ca997c9bf2ebee73250f955c6a4325cd724f0ce732e6d3058b6e66fbc887fc18ea5fc588729595356022327f8de0dc1a7c6de88500ab5ba19d010d0864fc61a23c23f2fc174f84715b29f20ae261b3c9023e8c2a67c67cbb9192b50d58c3dc8760cbc45dda83f5ca5a2fd440e1740f11903d6fac2c72dec3b7d628b2d22e7efc0986cf36d9eb2d210b17d70dcb495805aa90c1f2f67159f916b0a1ff8f557ef340b006b73afaa5d76b20016f87e7a713ddf2eba6f20620f0f2dc6ece52e6c2f39a4e21e338672f67351396c1959a679f2a6a9e1af777868275be05283b6ca12265aa532c8587f0e7e5188c2968cf9bf0b7f42c00d8ce2e1cd01e586fa60eb0a7114163acec87b320ab292c304decf7034ef68cb38d0a8e9253a181f2138781c2bfc98f7eb22135996c000200ee0000000015752a00000000012a05f20039f0bd56c1439a22ee90b4972c16b7868d16198101000000fa2cce4e0c4c31fefdc7fa89c2c1d1c4663c2d7d1f14aa03e2feeccef437e227658f5f77a35f6afb74a1fd9b29bb1be034ff21eb7696793ad0e7d4a30a4dd30d1963d72a2e98e40d89e3e905424a0a688c67f78e540d0d92477f00c424ab7e0183eb9c40e9223310a224d4cc0fd529699aa9fa76a85323a84ecdad2e635a7e85672a24f09aebf9c2dced55812b4087cd0363b9db256982c52286af541e270dbb3c23bc281cfc4282facf0b1779c7a3adcb7f76983f2e30d50dc7a93951c6ca27723610195122"
            )
        );
        vm.stopPrank();
    }

    function makeDeposit(bool migrated) internal {
        // fork block: 110_198_152
        // tx: 0x0fe989fb4b37e69cbd7b32c71fa90cadd75bc01f9681fc2cfcbf3d82472755cd
        // hex"1f5bf731b361368ec5d621072138465c77c4f868b47cdbc719b2aa0f67a4bc6c0a825b40be1aeae4f5f77a01d48034fdc4800221fee465b2694ab5fb10f9a45b000000048800000000000000000000000000000000000002540be4002e56b2600eba70524189068e4017d7592a9219ec52d352a77cd6d8a78aea9c91173e44c1ded009051f822b0c3e39349d6cb0e26a85f1abee66c56b1b327157ef0e73c6335469f5b74904155f5ec4415d8cdaf74870d82560752fb4c03016ae790acb51380d0e6fa27aebf2f06b5c308625efaf678ebfae35100d530f1137b9fc0b352e5039c59e965967390151a9d60c1e9ae8992ad033f82ee69d4def97781c259aa0be6b31162571c11fc231358c74e3e9a53dcfac89db8102a49f04e4f736184b36ae5a520bc57d69811ea019995173d7100b4abea1a7f75b5a4655b186ea0d820a3c6d747d94e3379e20943d82800a7502a4849c7c0846f054d814de8ac91fbe0697f995309ecafb7bc3302a99581bd8602c63fa18543cf24a5fe1ec37472caecff5c46955a582702a548c09e6f15f5eae4434962b2f0bb3a5dbfd6414df0ee2b0a343502a2f6a4c5556ac99c29d6d604f2a6f164eaabe4857b73e54abc60116bc9cb1031fdd46d7eb37a94263e27258a40a5f73f12ede2bc028da3f67ec1569c9c26befb3fbe843f767fb73967e95202353687424991cdcc1b3164b0a582314fc6d7ede4d33f0a569bce9e530f30aafc34f30d17775bec09a300c8c0618111a856e96dc7318c2d6c7f650f74ab8bdc507c42dddadac9947184397cbd92702714030ac97ea63f5b31ea59c41ca410eef162c4bc806ee842fd9025908d9b026bc7a55b210c32732908838acefccbe7f4d3bf4027422f6c7a7ee2137437b1a000300ee00000000173eed80000000006516da0b39f0bd56c1439a22ee90b4972c16b7868d1619810100000094d9ac2eb4cbd1757ebc9314d2e2cb7138d370500aab6d5ad402006da78f8f1abc1a7d244119a1ab107f27ec85025facd57d18821eefc30777ec31b6251b5d1eb58b7f2f37beb834b544f5474ff9a4284bdc3e3b9f32f78596044850fc9a6faaa3ba456343260839922c3f18fe5bf805562ea915771af825e63b2c7dd6a9989a5f8cc25be40160155a36d75a8bff971142729c70e3ba32f3dfb429d33efcffe261023af04234e0a7e7c9fdc92755b8555ca046ba77dc57487ed1ccc0a8c4a6e2e1821900ffef441154ec44e2f4bfe760fae618bd84157a49f9a72a0a79c41110395c79bf55502e7219e51daee469fdc14810beb9debd429a620cf39e17c7b497e94571d78122"
        if (migrated) {
            deal(usdc_addr, address(0x39F0bD56c1439a22Ee90b4972c16b7868D161981), 10_400_000);
        } else {
            deal(bob_addr, address(0x39F0bD56c1439a22Ee90b4972c16b7868D161981), 10_400_000_000_000_000_000);
        }
        vm.startPrank(relayer_addr);
        address(pool).call(
            abi.encodePacked(
                pool.transact.selector,
                hex"1f5bf731b361368ec5d621072138465c77c4f868b47cdbc719b2aa0f67a4bc6c0a825b40be1aeae4f5f77a01d48034fdc4800221fee465b2694ab5fb10f9a45b000000048800000000000000000000000000000000000002540be4002e56b2600eba70524189068e4017d7592a9219ec52d352a77cd6d8a78aea9c91173e44c1ded009051f822b0c3e39349d6cb0e26a85f1abee66c56b1b327157ef0e73c6335469f5b74904155f5ec4415d8cdaf74870d82560752fb4c03016ae790acb51380d0e6fa27aebf2f06b5c308625efaf678ebfae35100d530f1137b9fc0b352e5039c59e965967390151a9d60c1e9ae8992ad033f82ee69d4def97781c259aa0be6b31162571c11fc231358c74e3e9a53dcfac89db8102a49f04e4f736184b36ae5a520bc57d69811ea019995173d7100b4abea1a7f75b5a4655b186ea0d820a3c6d747d94e3379e20943d82800a7502a4849c7c0846f054d814de8ac91fbe0697f995309ecafb7bc3302a99581bd8602c63fa18543cf24a5fe1ec37472caecff5c46955a582702a548c09e6f15f5eae4434962b2f0bb3a5dbfd6414df0ee2b0a343502a2f6a4c5556ac99c29d6d604f2a6f164eaabe4857b73e54abc60116bc9cb1031fdd46d7eb37a94263e27258a40a5f73f12ede2bc028da3f67ec1569c9c26befb3fbe843f767fb73967e95202353687424991cdcc1b3164b0a582314fc6d7ede4d33f0a569bce9e530f30aafc34f30d17775bec09a300c8c0618111a856e96dc7318c2d6c7f650f74ab8bdc507c42dddadac9947184397cbd92702714030ac97ea63f5b31ea59c41ca410eef162c4bc806ee842fd9025908d9b026bc7a55b210c32732908838acefccbe7f4d3bf4027422f6c7a7ee2137437b1a000300ee00000000173eed80000000006516da0b39f0bd56c1439a22ee90b4972c16b7868d1619810100000094d9ac2eb4cbd1757ebc9314d2e2cb7138d370500aab6d5ad402006da78f8f1abc1a7d244119a1ab107f27ec85025facd57d18821eefc30777ec31b6251b5d1eb58b7f2f37beb834b544f5474ff9a4284bdc3e3b9f32f78596044850fc9a6faaa3ba456343260839922c3f18fe5bf805562ea915771af825e63b2c7dd6a9989a5f8cc25be40160155a36d75a8bff971142729c70e3ba32f3dfb429d33efcffe261023af04234e0a7e7c9fdc92755b8555ca046ba77dc57487ed1ccc0a8c4a6e2e1821900ffef441154ec44e2f4bfe760fae618bd84157a49f9a72a0a79c41110395c79bf55502e7219e51daee469fdc14810beb9debd429a620cf39e17c7b497e94571d78122"
            )
        );
        vm.stopPrank();
    }

    function makeDirectDeposit(bool migrated) internal returns (uint64 retval) {
        // fork block: 110_198_152
        // tx: 0xa0e620d0bf8c85474bf42d955be64e25ef452265855f572f7bfc5ed336170dd4
        address actor = address(0x39F0bD56c1439a22Ee90b4972c16b7868D161981);
        uint256 amount;
        address token_addr;
        string memory zk_addr = "EnjxfGpbEGhryjoyLdQKRTm5JEEqpaaqHtgydJiDeKgaDuChHtUJcaDPZ875bYu";
        if (migrated) {
            amount = 4_000_000;
            token_addr = usdc_addr;
        } else {
            amount = 4_000_000_000_000_000_000;
            token_addr = bob_addr;
        }
        if (IERC20(token_addr).balanceOf(actor) < amount) {
            deal(token_addr, actor, amount);
        }
        vm.startPrank(actor);
        IERC20(token_addr).approve(address(queue_proxy), amount);
        vm.recordLogs();
        queue_proxy.directDeposit(actor, amount, zk_addr);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        uint8 log_index = 255;
        for (uint8 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == 0xcde1b1a4bd18b6b8ddb2a80b1fce51c4eee01748267692ac6bc0770a84bc6c58) {
                log_index = i;
            }
        }
        (,,, retval) = abi.decode(entries[log_index].data, (address, bytes10, bytes32, uint64));
        vm.stopPrank();
    }

    function executeDirectDeposit() internal {
        // fork block: 110_198_152
        // tx: 0x937123ff34b4b6319551544efb2eedf7f5e42681fc30a359bce072f4975f4738
        // hex"2af410a6d410122852e24ea624e2ad2176339796f31c4aab1daaaee9045dc8a60000000000000000000000000000000000000000000000000000000000000260284cff4ea61a59c5d5bd151488ab63efea2620b1d6f726857fbd1299392bbbb70c613ee006ec93d33469ea7671a5ff0da01752937c3c38ee02384f5ca4e270802c0ca16adeb724a68d9f3cb033423d7538a08182eb8db99f2c2ed24d666e2b5d23ea64fcd7d6ec87634045e4d432c4a0f6bbf13cbfa34f9e8a008ff2bfde21f102a14c1129e3490bcda70e9c4bdef2ce2022d58be49c1182cc72cbf9d1fba1f5044617f800b995bad6f77ed00042da35db97d4562dc6486f59d4db8ef2eef3e4128fd61249cf5f2ad914e6759272a47a9c069697e7baaec638ff0f7235f78acc1585deedc39ddff547159219888494256bf3e40b3563ebd6faa81d9db768f0c921c7b7a64724da6ff3c94f4687c97854a12d8e77ad9a59ea51a2598221718f8b1fe4135b19ef791016e5e7b1e2b90aea819ef158f2fc703270a10caeaaf53e9e1d4017b06e346942008de590861fb9c114ce739d1e1efa0c4346c830e59d46aa124c0cd7e42d5620deb2ab18e042987f21fdaacb8596f6561de854c8af818fa80046ff8fdf53d3639ba0f0ef9d96559f3d326d0a3189f498e2c413d5016001b62be5c0c8dc647865af10b5c979bc01dc858a48e293adfeb6c964eb3059c210ec1f070036e9a1f9e7ba8b9730fa1e118e819a476c2952513533986ba19914d7cc20f6a73c9da3511074edec6299b35a4d02dd47bf2955ea5303c71bd6248592581cb1d20bfd4d0d839672cd006bd82c8201343915b1b8435a18c74ffff0ce936600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000005"
        vm.startPrank(relayer_addr);
        address(pool).call(
            abi.encodePacked(
                pool.appendDirectDeposits.selector,
                hex"2af410a6d410122852e24ea624e2ad2176339796f31c4aab1daaaee9045dc8a60000000000000000000000000000000000000000000000000000000000000260284cff4ea61a59c5d5bd151488ab63efea2620b1d6f726857fbd1299392bbbb70c613ee006ec93d33469ea7671a5ff0da01752937c3c38ee02384f5ca4e270802c0ca16adeb724a68d9f3cb033423d7538a08182eb8db99f2c2ed24d666e2b5d23ea64fcd7d6ec87634045e4d432c4a0f6bbf13cbfa34f9e8a008ff2bfde21f102a14c1129e3490bcda70e9c4bdef2ce2022d58be49c1182cc72cbf9d1fba1f5044617f800b995bad6f77ed00042da35db97d4562dc6486f59d4db8ef2eef3e4128fd61249cf5f2ad914e6759272a47a9c069697e7baaec638ff0f7235f78acc1585deedc39ddff547159219888494256bf3e40b3563ebd6faa81d9db768f0c921c7b7a64724da6ff3c94f4687c97854a12d8e77ad9a59ea51a2598221718f8b1fe4135b19ef791016e5e7b1e2b90aea819ef158f2fc703270a10caeaaf53e9e1d4017b06e346942008de590861fb9c114ce739d1e1efa0c4346c830e59d46aa124c0cd7e42d5620deb2ab18e042987f21fdaacb8596f6561de854c8af818fa80046ff8fdf53d3639ba0f0ef9d96559f3d326d0a3189f498e2c413d5016001b62be5c0c8dc647865af10b5c979bc01dc858a48e293adfeb6c964eb3059c210ec1f070036e9a1f9e7ba8b9730fa1e118e819a476c2952513533986ba19914d7cc20f6a73c9da3511074edec6299b35a4d02dd47bf2955ea5303c71bd6248592581cb1d20bfd4d0d839672cd006bd82c8201343915b1b8435a18c74ffff0ce936600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000005"
            )
        );
        vm.stopPrank();
    }

    function setLimits(address user, uint256 denominator) internal {
        vm.startPrank(owner);
        pool.setLimits({
            _tier: 100,
            _tvlCap: zkBobPoolCap / denominator,
            _dailyDepositCap: zkBobDailyDepositCap / denominator,
            _dailyWithdrawalCap: zkBobDailyWithdrawalCap / denominator,
            _dailyUserDepositCap: zkBobDailyUserDepositCap / denominator,
            _depositCap: zkBobDepositCap / denominator,
            _dailyUserDirectDepositCap: zkBobDailyUserDirectDepositCap / denominator,
            _directDepositCap: zkBobDirectDepositCap / denominator
        });
        address[] memory users = new address[](1);
        users[0] = user;
        pool.setUsersTier(100, users);
        vm.stopPrank();
    }

    function makeDepositOutOfNomination() internal returns (bool status) {
        // fork block: 110_198_152
        // tx: 0xe739c58da9e831c333a60f5686a8ef9b35325a0c773f73b4048226967ad257bd
        // hex"262e0b9055673f82d3e64b47274402db3245b95b20e2d6bc00c5f2b5404543241868fabc7ebc0847009d78305c328c7c110fbf8d83cd50aeed05457d52c131210000000489000000000000000000000000000000000000013d3202cb16132f50bd285ccd9d2c59e9baeb4bfef4b9026c06eb4710965149251ac526d7204fc0e661da1676b1818d31cbc19f4c71c9cd7b1950374048f88944e9c0c9a8047a3af29414c09b7c828cea2eb7f3b4b4efa71fff8bc3c09a4a34773b236d14099e3d8b8d2b6d36af5f039fc38ab71346a41d89ecce74ebef324b4cf96483e807b6cae8893d4a396ce839417bbaaa11f1bf93770c88bf423c279753e220461a0addddafd93a37391bb44478880c8a7731b2c9681d758bdd4d01d4a8c80ef1d0281805891738e0445f2f3ccdcbe1427bbd22928bc5a57bfbb3ade6da89c5cea821c06f594feb3b8eb9faf4c816cf727d66fb330bd9a199bfd4a112cf3756cd9d165fe5cf6d41ce5fed06f5420e7460497c9f10369342957d19a34d91b520f4800ecf07f21fdc4d8cbe2c3d22538ec906924c05e33aa90faed47078af28deffaa00092b699f766e23eab5508979e6d0a20b330b1bbd81aff7b8eb9714906fb2ea28c52b247ad8bfe9c2fe95aa5b51af6658e0d9d3de25984dfd3eab89f8d76fe414e622bc428731fcf107138f72a0bb031aa7d35e463de2cb6cd7eb882a163a2a1499bd129faf5fd75d1c8ab0cc960c00e026ba0ea76b68be1a75644309abb0c62e4a78f439c583ff3e6a05374ffb0aaea27160b23a0cd6bb03522ffc17a4eb0e2d0c234ae344e8cbb427ce3056bedaf9d9d081a6be858cb69ab659b39999f2e42e32d4cc8cc3435c7384e4a3cd35f216b522f95033c6b90937a6349790c29437000300ee000000001b6b0b00000000006516df3039f0bd56c1439a22ee90b4972c16b7868d161981010000005d1cb7e2cb65688e744ecbb007facdc0cc8d79704cb6da0faf5a3e48bb499729390f1f813baf9e63de79804e6c650e3ecad9689f1bd4821c3850964be448ed2054364fb86172efe3c8b3b9a11e4c7dd10f116ed4e009053c5f38ff62a7caad7d57bd7da93a5c74aafff4a50fc2e0a9e7f5991774ccc01004c95d8a9ba33f2a326abde6fdf7b4ade52ea444cc6c3d730895e19d70d07406db069442af348bf92b0da80f6cf62d702f4d51ac3c6460e238936a79bbdb130731053f1f4e132d6159d9adfcfa5b8bfa549fe471c57d66220874a3fbdee1ee29c3efafa6f73bc0bb0103a16fe881ee3bdfb1242e81633904315f903131380653b68e7ccda809925da973fa9b0a6c0d"
        address actor = address(0x39F0bD56c1439a22Ee90b4972c16b7868D161981);
        deal(usdc_addr, actor, 6_000_000);
        vm.startPrank(relayer_addr);
        (status,) = address(pool).call(
            abi.encodePacked(
                pool.transact.selector,
                hex"262e0b9055673f82d3e64b47274402db3245b95b20e2d6bc00c5f2b5404543241868fabc7ebc0847009d78305c328c7c110fbf8d83cd50aeed05457d52c131210000000489000000000000000000000000000000000000013d3202cb16132f50bd285ccd9d2c59e9baeb4bfef4b9026c06eb4710965149251ac526d7204fc0e661da1676b1818d31cbc19f4c71c9cd7b1950374048f88944e9c0c9a8047a3af29414c09b7c828cea2eb7f3b4b4efa71fff8bc3c09a4a34773b236d14099e3d8b8d2b6d36af5f039fc38ab71346a41d89ecce74ebef324b4cf96483e807b6cae8893d4a396ce839417bbaaa11f1bf93770c88bf423c279753e220461a0addddafd93a37391bb44478880c8a7731b2c9681d758bdd4d01d4a8c80ef1d0281805891738e0445f2f3ccdcbe1427bbd22928bc5a57bfbb3ade6da89c5cea821c06f594feb3b8eb9faf4c816cf727d66fb330bd9a199bfd4a112cf3756cd9d165fe5cf6d41ce5fed06f5420e7460497c9f10369342957d19a34d91b520f4800ecf07f21fdc4d8cbe2c3d22538ec906924c05e33aa90faed47078af28deffaa00092b699f766e23eab5508979e6d0a20b330b1bbd81aff7b8eb9714906fb2ea28c52b247ad8bfe9c2fe95aa5b51af6658e0d9d3de25984dfd3eab89f8d76fe414e622bc428731fcf107138f72a0bb031aa7d35e463de2cb6cd7eb882a163a2a1499bd129faf5fd75d1c8ab0cc960c00e026ba0ea76b68be1a75644309abb0c62e4a78f439c583ff3e6a05374ffb0aaea27160b23a0cd6bb03522ffc17a4eb0e2d0c234ae344e8cbb427ce3056bedaf9d9d081a6be858cb69ab659b39999f2e42e32d4cc8cc3435c7384e4a3cd35f216b522f95033c6b90937a6349790c29437000300ee000000001b6b0b00000000006516df3039f0bd56c1439a22ee90b4972c16b7868d161981010000005d1cb7e2cb65688e744ecbb007facdc0cc8d79704cb6da0faf5a3e48bb499729390f1f813baf9e63de79804e6c650e3ecad9689f1bd4821c3850964be448ed2054364fb86172efe3c8b3b9a11e4c7dd10f116ed4e009053c5f38ff62a7caad7d57bd7da93a5c74aafff4a50fc2e0a9e7f5991774ccc01004c95d8a9ba33f2a326abde6fdf7b4ade52ea444cc6c3d730895e19d70d07406db069442af348bf92b0da80f6cf62d702f4d51ac3c6460e238936a79bbdb130731053f1f4e132d6159d9adfcfa5b8bfa549fe471c57d66220874a3fbdee1ee29c3efafa6f73bc0bb0103a16fe881ee3bdfb1242e81633904315f903131380653b68e7ccda809925da973fa9b0a6c0d"
            )
        );
        vm.stopPrank();
    }

    function getVerificationValues() internal returns (VerificationValues memory) {
        uint256 snapshot = vm.snapshot();

        uint256 prev_dd_in = uint256(makeDirectDeposit(false));

        uint256 prev_balance = IERC20(bob_addr).balanceOf(address(pool));
        makeWithdrawal();
        uint256 new_balance = IERC20(bob_addr).balanceOf(address(pool));
        uint256 prev_withdrawal_diff = prev_balance - new_balance;

        prev_balance = new_balance;
        makeDeposit(false);
        new_balance = IERC20(bob_addr).balanceOf(address(pool));
        uint256 prev_deposit_diff = new_balance - prev_balance;

        prev_balance = new_balance;
        executeDirectDeposit();
        new_balance = IERC20(bob_addr).balanceOf(address(pool));
        uint256 prev_dd_out_diff = new_balance - prev_balance;

        prev_balance = new_balance;
        makeFeesWithdrawal();
        uint256 prev_fees = prev_balance - IERC20(bob_addr).balanceOf(address(pool));

        setLimits(relayer_addr, 1);
        ZkBobAccounting.Limits memory limits = pool.getLimitsFor(relayer_addr);

        vm.revertTo(snapshot);
        return VerificationValues({
            withdrawalDiff: prev_withdrawal_diff,
            depositDiff: prev_deposit_diff,
            fees: prev_fees,
            ddIn: prev_dd_in,
            ddOutDiff: prev_dd_out_diff,
            limits: limits
        });
    }

    function fakeUSDC() internal {
        // the new implementation does not contain `require` to check that
        // returned from ecrecover address is the same as the tokens originator.
        //
        // This is a workaround to use an existing deposit to verify the new pool
        // logic.
        address usdc_impl = deployCode("FiatTokenV2.sol:FiatTokenV2_1");
        bytes memory code = usdc_impl.code;
        vm.etch(EIP1967Proxy(payable(usdc_addr)).implementation(), code);
    }

    function run() external {
        if (block.number != 110_198_152) {
            return;
        }

        uint256 bobToUSDCshift = 10 ** (IERC20Metadata(bob_addr).decimals() - IERC20Metadata(usdc_addr).decimals());

        VerificationValues memory prev = getVerificationValues();

        migrate();

        require(pool.denominator() == (1 << 255) | 1000, "Incorrect denominator");

        uint256 dd_in = uint256(makeDirectDeposit(true));
        require(dd_in == prev.ddIn, "Input DD value does not match");

        uint256 prev_balance = IERC20(usdc_addr).balanceOf(address(pool));
        makeWithdrawal();
        uint256 new_balance = IERC20(usdc_addr).balanceOf(address(pool));
        require(prev_balance - new_balance == prev.withdrawalDiff / bobToUSDCshift, "Incorrect balance");

        prev_balance = new_balance;
        fakeUSDC();
        makeDeposit(true);
        new_balance = IERC20(usdc_addr).balanceOf(address(pool));
        require(new_balance - prev_balance == prev.depositDiff / bobToUSDCshift, "Incorrect balance");

        prev_balance = new_balance;
        executeDirectDeposit();
        new_balance = IERC20(usdc_addr).balanceOf(address(pool));
        require(new_balance - prev_balance == prev.ddOutDiff / bobToUSDCshift, "Incorrect balance");

        prev_balance = new_balance;
        makeFeesWithdrawal();
        new_balance = IERC20(usdc_addr).balanceOf(address(pool));
        require(prev_balance - new_balance == prev.fees / bobToUSDCshift, "Fees does not match");

        setLimits(relayer_addr, bobToUSDCshift);
        ZkBobAccounting.Limits memory limits = pool.getLimitsFor(relayer_addr);
        require(limits.tvl == prev.limits.tvl, "Incorrect tvl");
        require(limits.tvlCap == prev.limits.tvlCap, "Incorrect tvlCap limit");
        require(limits.dailyDepositCap == prev.limits.dailyDepositCap, "Incorrect dailyDepositCap limit");
        require(limits.dailyWithdrawalCap == prev.limits.dailyWithdrawalCap, "Incorrect dailyWithdrawalCap limit");
        require(limits.dailyUserDepositCap == prev.limits.dailyUserDepositCap, "Incorrect dailyUserDepositCap limit");
        require(limits.depositCap == prev.limits.depositCap, "Incorrect depositCap limit");
        require(
            limits.dailyUserDirectDepositCap == prev.limits.dailyUserDirectDepositCap,
            "Incorrect dailyUserDirectDepositCap limit"
        );
        require(limits.directDepositCap == prev.limits.directDepositCap, "Incorrect directDepositCap limit");

        bool retval = makeDepositOutOfNomination();
        require(retval == false, "Deposit must revert");
    }
}
