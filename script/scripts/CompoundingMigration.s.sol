// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "forge-std/StdAssertions.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "forge-std/Vm.sol";
import "./Env.s.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TransparentUpgradeableProxy as TUP} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPoolBOB.sol";
import "../../src/zkbob/utils/ZkBobAccounting.sol";
import "../../src/zkbob/ZkBobDirectDepositQueue.sol";
import "../../src/infra/UniswapV3Seller.sol";
import "../../src/zkbob/ZkBobPoolUSDC.sol";
import "@aave/aave-vault/src/ATokenVault.sol";
import "../../src/zkbob/ZkBobPoolUSDCMigrated.sol";

contract BOBPoolMigration is Script, StdCheats {
    ZkBobPoolUSDCMigrated pool = ZkBobPoolUSDCMigrated(0x72e6B59D4a90ab232e55D4BB7ed2dD17494D62fB);
    ZkBobDirectDepositQueue queue_proxy = ZkBobDirectDepositQueue(0x668c5286eAD26fAC5fa944887F9D2F20f7DDF289);
    address usdc_addr = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    address relayer_addr = address(0xc2c4AD59B78F4A0aFD0CDB8133E640Db08Fa5b90);
    address poolAddressesProvider = address(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
    uint256 D = 10 ** 12;
    address yieldAddress;

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
        require(queue_proxy == pool.direct_deposit_queue(), "Incorrect Direct Deposit queue proxy");

        vm.startPrank(deployer);
        ZkBobPoolUSDCMigrated poolImpl = new ZkBobPoolUSDCMigrated(
            pool_id, usdc_addr,
            transferVerifier, treeVerifier, batchDepositVerifier,
            address(queue_proxy)
        );
        ITokenSeller tokenSeller = pool.tokenSeller();
        ZkBobDirectDepositQueue queueImpl = new ZkBobDirectDepositQueue(address(pool), usdc_addr, 1);
        vm.stopPrank();

        vm.startPrank(owner);
        IERC20(usdc_addr).approve(address(pool), type(uint256).max);
        EIP1967Proxy(payable(address(pool))).upgradeTo(address(poolImpl));
        IERC20(usdc_addr).approve(address(pool), 0);
        EIP1967Proxy(payable(address(queue_proxy))).upgradeTo(address(queueImpl));
        pool.setTokenSeller(address(tokenSeller));
        vm.stopPrank();

        ATokenVault yieldVault = new ATokenVault(usdc_addr, 4546, IPoolAddressesProvider(poolAddressesProvider));
        deal(usdc_addr, address(this), 1_000_050 ether / D);
        address yieldProxyAddr = computeCreateAddress(address(this), vm.getNonce(address(this)));
        IERC20(usdc_addr).approve(yieldProxyAddr, type(uint256).max);
        bytes memory initData = abi.encodeWithSelector(
            ATokenVault.initialize.selector,
            address(owner),
            0.2 ether, // 20%
            "Wrapped BOB Yield Token",
            "wBYT",
            1_000_000 ether / D
        );
        TUP yieldProxy = new TUP(address(yieldVault), owner, initData);

        yieldAddress = address(yieldProxy);
        vm.prank(owner);
        pool.updateYieldParams(
            ZkBobCompoundingMixin.YieldParams({
                yield: address(yieldProxy),
                maxInvestedAmount: 50_000 ether / D,
                buffer: 400 ether / D,
                dust: uint96(0.5 ether / D),
                interestReceiver: address(this),
                yieldOperator: address(this)
            })
        );

    }

    function makeWithdrawal() internal {
        // fork block: 45_809_106
        // tx: 0x61bcfb2ef94ace5295c06a8b0e1093d78693b0beceaa34f1b98af3917dfb69c7
        // hex"af98908317b43afbe70cd5491c807c67e64f71bd3c3a7fe2ce6cb3ea66c7202e857a316c21dbc7eb61e2dfc783903ac08884a3328939a31fed1a93842af4a8275c8e451a0000003e84000000000000000000000000000000ffffff9609ed1900272610fa9e8167daee1fed4cca9b5250dc6fa3864fa32e9b415fd42c81d4fe1717e78993ddf69c8ddcb5bcf317879abe646d04e918c12df8f34a37346e1233a40b80a6c6943a894a72d342235b95fb172f407a7820d7cd1a4c54d65a825813cb184f4ab2e7efdca39a74b5079566ee056015fed83a76bebbf40050155d59240d0026b1b5cbd015fcf054926e3035f335a10d51a27e0dd165eba006ae514a725420825462ba3168316e352c21f53acfe04ca6b5737ce4376c0e5d00631c9c45111152d7a0125a0b369970c29dd2731e92e5c5b62c2d194615fc27fab7fbee42b12a978368f85fe1943151f4ecc781b5eb9bc2578dcf8f5fc30c7c0b650ea4f4f0021e591a9de9237ca70cc48c1ea15bb58749ad63900ae4b7755838cce7fedd0c1eb19c8baf3a9050897757684dd77c8333d0bfc7a2577047ea63879a40bf0c0d2a0b859505e319e8b8f11d4917df762a8b925a22da45fe40f1f94a6ddf6a8bc518291615363aaf82ef256140956b86b0e89fc63fb96991a22925a711db55524f1fcffe07de11f8c88726df0c00945dd56c71c7eed6509a13783ae2a1f78775ab29531528d6134f83dc454e84d45f8a2690773ae5728927ebde418d7245530bb92b7abe6b6677bcd0b1bcc9a35be9af7183e6b91a9477268ee5ccdbc6e4bead5107c8f0747c5ab41ea78dd429d03584f0b04bc040d47d65820035249c27775f620776aac9a0dc9b1f2fc577341eec0fe950c3419e91f160de932e725ae1b29600000200ee0000000005f5e1000000000000000000e85d92be7478d3784851d25d1298cd4f424ee3eb01000000b7ae5d7c369246e8bdc61fef5504ce3db409493f0398d3e415ec360c8ed407270b90f6bb2693334234c3e0275758944b9d3834b38aa961e53007b806d27079249b0da2194dcab051de0f6af71f0aef8d23c8425760ff20b4a7d6c0d0477cd67b651f693f281ccffdce900a21c70c1e8fc95b3daab214c8b5a201c0babaefb66cebc205eb72df40d37c0149decf648017a34600e6b11f00bc64294cd7049809bb37493b03fab11ac3b1c820a2e961694268dff513190fa5fbaab9630fb251e68ef997446db6c5"
        vm.roll(45_809_106);
        vm.startPrank(relayer_addr);
        address(pool).call(
            abi.encodePacked(
                pool.transact.selector,
                hex"af98908317b43afbe70cd5491c807c67e64f71bd3c3a7fe2ce6cb3ea66c7202e857a316c21dbc7eb61e2dfc783903ac08884a3328939a31fed1a93842af4a8275c8e451a0000003e84000000000000000000000000000000ffffff9609ed1900272610fa9e8167daee1fed4cca9b5250dc6fa3864fa32e9b415fd42c81d4fe1717e78993ddf69c8ddcb5bcf317879abe646d04e918c12df8f34a37346e1233a40b80a6c6943a894a72d342235b95fb172f407a7820d7cd1a4c54d65a825813cb184f4ab2e7efdca39a74b5079566ee056015fed83a76bebbf40050155d59240d0026b1b5cbd015fcf054926e3035f335a10d51a27e0dd165eba006ae514a725420825462ba3168316e352c21f53acfe04ca6b5737ce4376c0e5d00631c9c45111152d7a0125a0b369970c29dd2731e92e5c5b62c2d194615fc27fab7fbee42b12a978368f85fe1943151f4ecc781b5eb9bc2578dcf8f5fc30c7c0b650ea4f4f0021e591a9de9237ca70cc48c1ea15bb58749ad63900ae4b7755838cce7fedd0c1eb19c8baf3a9050897757684dd77c8333d0bfc7a2577047ea63879a40bf0c0d2a0b859505e319e8b8f11d4917df762a8b925a22da45fe40f1f94a6ddf6a8bc518291615363aaf82ef256140956b86b0e89fc63fb96991a22925a711db55524f1fcffe07de11f8c88726df0c00945dd56c71c7eed6509a13783ae2a1f78775ab29531528d6134f83dc454e84d45f8a2690773ae5728927ebde418d7245530bb92b7abe6b6677bcd0b1bcc9a35be9af7183e6b91a9477268ee5ccdbc6e4bead5107c8f0747c5ab41ea78dd429d03584f0b04bc040d47d65820035249c27775f620776aac9a0dc9b1f2fc577341eec0fe950c3419e91f160de932e725ae1b29600000200ee0000000005f5e1000000000000000000e85d92be7478d3784851d25d1298cd4f424ee3eb01000000b7ae5d7c369246e8bdc61fef5504ce3db409493f0398d3e415ec360c8ed407270b90f6bb2693334234c3e0275758944b9d3834b38aa961e53007b806d27079249b0da2194dcab051de0f6af71f0aef8d23c8425760ff20b4a7d6c0d0477cd67b651f693f281ccffdce900a21c70c1e8fc95b3daab214c8b5a201c0babaefb66cebc205eb72df40d37c0149decf648017a34600e6b11f00bc64294cd7049809bb37493b03fab11ac3b1c820a2e961694268dff513190fa5fbaab9630fb251e68ef997446db6c5"
            )
        );
        vm.stopPrank();
    }

    function makeDeposit() internal {
        // fork block: 45_807_232
        // tx: 0x480f192b0b42697b691d206b35ecaeadd8687adac61868255ca08e9eaba4c211
        // hex"af98908311e59127807b58834aecd0dd19d93ffba821f2c936cfcfedb9af6c0f54f52d08268d192b852bf2556cc605d55a7d5caf378a8c6c7087fd933dee0ed381fa2fd90000003e83800000000000000000000000000000000000e699d6eef01172c9de3be3a501506e54455cc7bb2f35f3c4fca30eebb1649390ad7f922e932604c05745df2460e00a4cee06c62b0b5c860b74fe2c3cb68d64d02ab4b179f4201e837963c2911e0b848ff7779a1298297095b25ea3a504218746774067e6390a571aca8bbd7b11bb760739d29dd0e7190ebc31da1d3934884006efa033cfee22eed3516c4b32ceeb06ea57f8c04e33dd8582741a08ebeb94e92b04451ee4911a3ad4fd9a7c3905dcacce9329e1391c16b5fb53069cc55ab53b8674adeccdae10d036361edda9117bf47565d47b6cc5c7d4cade39d75631ebc3744098c0ffc82a4216eb18bbcc3d206055b0e4c229792e2aee0aa8c2e8078bb6c12a1131c07c034f12f7e76202e123f38795d68a218995198573e70a34fceabbccd79e2e22292afc0e2b6784e8793ee35728bb147c9645230c4b2fa4ba3d6c60e46d08721ca60f21fe8394dd82893ac7fbcb444f71e12910102129011f2121de1105b786e12b24c4b4f81d410a877cdfae03d544d6ebb0e4536ca8edb312cb3b33e26f65faae2fd993f182091f397749504771d15f7201f9ba7ffdbd4ed81311450df4ba0f1506487915376cb39d10cbb088f1656aa012aaf5d707ce252daf5a7b0d42e432ea14a54f1c30a70ee65027f74329a176ffe902a7e0b5227e27846c9d8bc5b6f91311019551b5ae3594dd593ed424db9590053da493f203e22f4bb26748fc7643d703f99117fefa57e757e3a6cf512cf1337ebf9957e6fa9be54e7bbd84a1255f32000300ee0000000005f5e1000000000064c9e7b7bd21e381b8ebfeb3eb6801a5fff787c8264f0003010000003c0cb2123aaba958fdc98f1f4c2659eec7eda3aa2edc4d9d8e34b6437158212446d9f005e4f687be4232095203454c576991f3feacd2567c17ec0329e2b52516e8c86e2a080c77fccd7e577b9a871742dd8f459e45ae59ed87c2fbe6fac75427b348132194ef81a3d836adaaf12e57a326873a0a9c6e26351ebbf886ab322b04484b06ec5a98842c764fe0fd7ff26b501024eedc5180c7d56451c6873ddea880aef618fd3e97bd8f39e240a2cc2d90a8068eae3b36f71c970bdc996bb8c2301b6762f889e286c4f6496eae60748118e1289bb80bf7bbe5cd1be3ab9ea9ede016bc82328d3306fb9cd09b01f43e59a167a694a7f24309206581880056efef611531d8d56c4b55"
        deal(usdc_addr, address(0x39F0bD56c1439a22Ee90b4972c16b7868D161981), 10_100_000);
        vm.roll(45_807_232);
        vm.startPrank(relayer_addr);
        address(pool).call(
            abi.encodePacked(
                pool.transact.selector,
                hex"af98908311e59127807b58834aecd0dd19d93ffba821f2c936cfcfedb9af6c0f54f52d08268d192b852bf2556cc605d55a7d5caf378a8c6c7087fd933dee0ed381fa2fd90000003e83800000000000000000000000000000000000e699d6eef01172c9de3be3a501506e54455cc7bb2f35f3c4fca30eebb1649390ad7f922e932604c05745df2460e00a4cee06c62b0b5c860b74fe2c3cb68d64d02ab4b179f4201e837963c2911e0b848ff7779a1298297095b25ea3a504218746774067e6390a571aca8bbd7b11bb760739d29dd0e7190ebc31da1d3934884006efa033cfee22eed3516c4b32ceeb06ea57f8c04e33dd8582741a08ebeb94e92b04451ee4911a3ad4fd9a7c3905dcacce9329e1391c16b5fb53069cc55ab53b8674adeccdae10d036361edda9117bf47565d47b6cc5c7d4cade39d75631ebc3744098c0ffc82a4216eb18bbcc3d206055b0e4c229792e2aee0aa8c2e8078bb6c12a1131c07c034f12f7e76202e123f38795d68a218995198573e70a34fceabbccd79e2e22292afc0e2b6784e8793ee35728bb147c9645230c4b2fa4ba3d6c60e46d08721ca60f21fe8394dd82893ac7fbcb444f71e12910102129011f2121de1105b786e12b24c4b4f81d410a877cdfae03d544d6ebb0e4536ca8edb312cb3b33e26f65faae2fd993f182091f397749504771d15f7201f9ba7ffdbd4ed81311450df4ba0f1506487915376cb39d10cbb088f1656aa012aaf5d707ce252daf5a7b0d42e432ea14a54f1c30a70ee65027f74329a176ffe902a7e0b5227e27846c9d8bc5b6f91311019551b5ae3594dd593ed424db9590053da493f203e22f4bb26748fc7643d703f99117fefa57e757e3a6cf512cf1337ebf9957e6fa9be54e7bbd84a1255f32000300ee0000000005f5e1000000000064c9e7b7bd21e381b8ebfeb3eb6801a5fff787c8264f0003010000003c0cb2123aaba958fdc98f1f4c2659eec7eda3aa2edc4d9d8e34b6437158212446d9f005e4f687be4232095203454c576991f3feacd2567c17ec0329e2b52516e8c86e2a080c77fccd7e577b9a871742dd8f459e45ae59ed87c2fbe6fac75427b348132194ef81a3d836adaaf12e57a326873a0a9c6e26351ebbf886ab322b04484b06ec5a98842c764fe0fd7ff26b501024eedc5180c7d56451c6873ddea880aef618fd3e97bd8f39e240a2cc2d90a8068eae3b36f71c970bdc996bb8c2301b6762f889e286c4f6496eae60748118e1289bb80bf7bbe5cd1be3ab9ea9ede016bc82328d3306fb9cd09b01f43e59a167a694a7f24309206581880056efef611531d8d56c4b55"
            )
        );
        vm.stopPrank();
    }

    function makeTransfer() internal {
        // fork block: 45_809_098
        // tx: 0x480f192b0b42697b691d206b35ecaeadd8687adac61868255ca08e9eaba4c211
        // hex"af9890832b440bfdc65d63874e794b5846db1f0d715c3e57594c3b40779392f9e8f2804e13f7a6a35405289d02397198fee7d091df5527c583b5cabef8abbe2236e009f00000003e84000000000000000000000000000000fffffffffa0a1f002518261802c9b3d364810f070b4def748c6b314129d02e58892d20e05a860baa04523401bdc24bdb1ed1f5334bb5a073644634dcb47d8fa6323a4ed90e14c52d09f76ba7f99f1ebf32504393224565540c1df278e7de4fa3b4d20f6795b62578276b1540e08388f9b81e11cbb1e217fa0da882f3c4bab34eb8ad4b4734b056a5018e1e5383ed847fde53c70119a901e93875ad28d4bc8e58f407e55cfaa637530847b9b8b311cdaf14ed0bb0665b19f89c5d5bd6b1fabc29051d74f54c1fa7e02f04c365086ba226ddff151642fa58c27d2908d9f4d0ad8c2f9b1782ea4714042de3c201edb3b0d1a9fa4ca51986612ee511c70be112eebffbaafe0ab96fbe4407762164d43ffa67cca6db4740088652e7e9945c5b21ac81aff6b8aaa4d2a24819c7ae959549f2c899984b20deaea05bd3139e4932854351a47ee11579b8fb5b230fcd79218cd888ca8db441a5d38b82bd03586e752612613e072e39c49ddd9d045d8373bdcd957398e08d18a93b4a5f5443df6f8cfb1c87079d2c1e18f92b241a2098a2c6163279ced2e89666a5eeaeb177a5b5660e6a932144518db81d470d156626303c9dd7e017a7da54a6dbd60d3ae299009d05d5128854b66394e5bea5214da1e7566db51d8b7f04124a1581a04df8c1b8f8050e82b6cd2d96ceb2b70420b23c6ffadc44cabc36b9a6317e1e17d20b47881f5026ad69e8c992a78b87e7136b8a8315312204258fc887afe47b47459c8d44ba733d6c870b1a382f3c01a10001017e0000000005f5e10002000000712fa952bb8ed3830abb53f60325b1fd9af0abb231286c8fc5053a3b52f899049e53ee628335ba394be2955b42a2d66463353372fa7ec4b82acd409bed4ca50924aea6bf432f8c5930ec4a720a4f2408db5b7e8c7d05439023eb22f8f5bb5e10f54faffb6f9b7effe77290d825c2dfefc72aa6304e21513f6533479c48f22936d4bf2e039aad6fbc427e7336dd10dd1950ed6c3a47ad5e8ade3b2db8999b2faa8c3c12997ff3920ca7efa3a20730f58dbb9408ed5387811c7dd56db95b0bc62125ae37b54e756d50adef219d5ab476baf54e8c486809d1110c1c2ffac047c7131cba663fa3e1078885d7cf54de25da4ac49c3018173fdb80603c9cb7544b16c1eb4ede8ec1987028fe5d058339a4c5482a1c9d338783b34c251087dcadacd707abe938c2a304539e6f06285f82c1ef88b9c6778c2cbd16c9b7b09c5361e552a2d7e4dddce7d63a57b827582227eadf5893d2f2e5c9e6a022e66da52e304f68c161135dbf5e3d2114e41b929004c5eae3575c"
        vm.roll(45_809_098);
        vm.warp(block.timestamp + 5598); // (45_809_098 - 45_807_232) * 3 = 5598
        vm.startPrank(relayer_addr);
        address(pool).call(
            abi.encodePacked(
                pool.transact.selector,
                hex"af9890832b440bfdc65d63874e794b5846db1f0d715c3e57594c3b40779392f9e8f2804e13f7a6a35405289d02397198fee7d091df5527c583b5cabef8abbe2236e009f00000003e84000000000000000000000000000000fffffffffa0a1f002518261802c9b3d364810f070b4def748c6b314129d02e58892d20e05a860baa04523401bdc24bdb1ed1f5334bb5a073644634dcb47d8fa6323a4ed90e14c52d09f76ba7f99f1ebf32504393224565540c1df278e7de4fa3b4d20f6795b62578276b1540e08388f9b81e11cbb1e217fa0da882f3c4bab34eb8ad4b4734b056a5018e1e5383ed847fde53c70119a901e93875ad28d4bc8e58f407e55cfaa637530847b9b8b311cdaf14ed0bb0665b19f89c5d5bd6b1fabc29051d74f54c1fa7e02f04c365086ba226ddff151642fa58c27d2908d9f4d0ad8c2f9b1782ea4714042de3c201edb3b0d1a9fa4ca51986612ee511c70be112eebffbaafe0ab96fbe4407762164d43ffa67cca6db4740088652e7e9945c5b21ac81aff6b8aaa4d2a24819c7ae959549f2c899984b20deaea05bd3139e4932854351a47ee11579b8fb5b230fcd79218cd888ca8db441a5d38b82bd03586e752612613e072e39c49ddd9d045d8373bdcd957398e08d18a93b4a5f5443df6f8cfb1c87079d2c1e18f92b241a2098a2c6163279ced2e89666a5eeaeb177a5b5660e6a932144518db81d470d156626303c9dd7e017a7da54a6dbd60d3ae299009d05d5128854b66394e5bea5214da1e7566db51d8b7f04124a1581a04df8c1b8f8050e82b6cd2d96ceb2b70420b23c6ffadc44cabc36b9a6317e1e17d20b47881f5026ad69e8c992a78b87e7136b8a8315312204258fc887afe47b47459c8d44ba733d6c870b1a382f3c01a10001017e0000000005f5e10002000000712fa952bb8ed3830abb53f60325b1fd9af0abb231286c8fc5053a3b52f899049e53ee628335ba394be2955b42a2d66463353372fa7ec4b82acd409bed4ca50924aea6bf432f8c5930ec4a720a4f2408db5b7e8c7d05439023eb22f8f5bb5e10f54faffb6f9b7effe77290d825c2dfefc72aa6304e21513f6533479c48f22936d4bf2e039aad6fbc427e7336dd10dd1950ed6c3a47ad5e8ade3b2db8999b2faa8c3c12997ff3920ca7efa3a20730f58dbb9408ed5387811c7dd56db95b0bc62125ae37b54e756d50adef219d5ab476baf54e8c486809d1110c1c2ffac047c7131cba663fa3e1078885d7cf54de25da4ac49c3018173fdb80603c9cb7544b16c1eb4ede8ec1987028fe5d058339a4c5482a1c9d338783b34c251087dcadacd707abe938c2a304539e6f06285f82c1ef88b9c6778c2cbd16c9b7b09c5361e552a2d7e4dddce7d63a57b827582227eadf5893d2f2e5c9e6a022e66da52e304f68c161135dbf5e3d2114e41b929004c5eae3575c"
            )
        );
        vm.stopPrank();
    }

    function run() external {
        if (block.number != 45_807_231) {
            return;
        }

        migrate();

        makeDeposit();
        uint256 poolBalance = IERC20(usdc_addr).balanceOf(address(pool));
        pool.rebalance(0, type(uint256).max);
        uint256 newPoolBalance = IERC20(usdc_addr).balanceOf(address(pool));
        uint256 yieldBalance = IERC4626(yieldAddress).convertToAssets(IERC4626(yieldAddress).balanceOf(address(pool)));
        assert(newPoolBalance == 400 ether / D); // equal to buffer
        assert(yieldBalance + newPoolBalance == poolBalance);
        makeTransfer();

        makeWithdrawal();
        newPoolBalance = IERC20(usdc_addr).balanceOf(address(pool));
        uint256 newYieldBalance =
            IERC4626(yieldAddress).convertToAssets(IERC4626(yieldAddress).balanceOf(address(pool)));
        assert(newPoolBalance == 400 ether / D); // equal to buffer
        uint256 claimed = pool.claim(0);
        assert(yieldBalance + claimed == newYieldBalance);
        assert(claimed > 0);
    }
}
