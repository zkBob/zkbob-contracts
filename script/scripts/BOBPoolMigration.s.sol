// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "forge-std/Vm.sol";
import "./Env.s.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPoolBOB.sol";
import "../../src/zkbob/ZkBobPoolUSDCMigrated.sol";
import "../../src/zkbob/utils/ZkBobAccounting.sol";
import "../../src/zkbob/ZkBobDirectDepositQueue.sol";
import "../../src/utils/UniswapV3Seller.sol";

contract BOBPoolMigration is Script, StdCheats {
    ZkBobPoolBOB pool = ZkBobPoolBOB(0x72e6B59D4a90ab232e55D4BB7ed2dD17494D62fB);
    ZkBobDirectDepositQueue queue_proxy = ZkBobDirectDepositQueue(0x668c5286eAD26fAC5fa944887F9D2F20f7DDF289);
    address bob_addr = address(0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B);
    address usdc_addr = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    address relayer_addr = address(0xc2c4AD59B78F4A0aFD0CDB8133E640Db08Fa5b90);

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
        UniswapV3Seller seller = new UniswapV3Seller(uniV3Router, uniV3Quoter, usdc_addr, 500, address(0), 0);
        ZkBobDirectDepositQueue queueImpl = new ZkBobDirectDepositQueue(address(pool), usdc_addr, 1);
        vm.stopPrank();

        bytes memory migrationData = abi.encodePacked(poolImpl.migrationToUSDC.selector);

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
        // fork block: 44_681_944
        // tx: 0x907d94b7075935e4e02648e6aeb13e6d19dbc1ef7eaffd87473a1235aae9c573
        // hex"0ae68f2e728abdad672dbc30f6f27303a50c90420bb862bb5c6fca3ce073af51060f958c031100d536773bf594fb6c4bd30dd6bfbb6ef37b1b73bbd8639c0717000000371e800000000000000000000000000000fffffd12431557001643727cb79bd7cb0ffcd35dee340100625630ad15bace55d78375b858006b02215473829367c910e2d0a6a473b4934e06db79fd48642896c3638cf008b1b5ec0132ef0332238cc8af63d5dc591dfa78578e239a7b7a9b8b9eb9dce194d6a6121c4a2c0e426e4cf50fdae37c1cf71bd6f472e0e42985182c8397f0f46d066dda1446726eebf544143c19dc18eaf1a776ed175390bde50c43c573646a94b4eaf407c3f521cc303585534e742fbe8126b375b9a3e69b941969ea2de952cc8a4ade02b7804e4116dbad9cecc26231985617aa27962ea5ef51cc021c239ce6e0662d01fd19941ef75ead0b92880b80cf2fc76a8f56667915fbd8eb0c894ee8cb87f40ff1867a1eb97b0869e258692f45b001759c0f41d1283251adc9dfe1d1a0e73209655d5d714f494ec56d6d43eafc34442f731d442aa63bf9d0230d5a68e215ef1d155f9ff8678f40f21e3af39dd1268c43061400205fd4b91ca2c467470a6f712ff295498b1fa4142025aaa8935f570b8512f4597838e8dc28cdb6ce0c1d1013127dc5ff708b011cd1bbfc58b2e671477a882a9f2418fd5a13d184722d83b5ba1dd06ea34ca33b8034bf5cffa5a9bcf9f014c9e03478ca92fede0929989c311d173f16be076938004b4826a3893c91c07c097b258ad491b2ebc8591a5f0db03211db7e23689f8f49f8784900f1abd195c5ae0143b83c2ea4f73f5873eee3f5c32ba0fee6093d30aca03ad93a8c06f148491f7654b89903e67cb04e18451a1682000200ee0000000005f5e100000000003b9aca0049d8735616f328843ef53b844fd429c2ff4e940901000000cf6f66cac9f03b13243262f365e44d00aae2eac80c6cd01fa05acac76829521ee4fc010b3056e0ea4da5886436010904659e61789e83a0dbad026af775eb0c192f6e0c159c3a47ede3daa77de6e63b60c9d74a6dedaef78120396f2512d113485bb3639524d1f211fdf5fc4fbb32e9eaf205a38626741762e9c2a23fbc4b32dc98db6e07d0f3c40deac704de64d0dfacb9844010dcfc666edad0b92f04ae6aead1b84b6f92a91b58001955074d28b0feb442551e6d179f8216a3730d642b1f7555f76f76974c"
        vm.startPrank(relayer_addr);
        address(pool).call(
            abi.encodePacked(
                pool.transact.selector,
                hex"0ae68f2e728abdad672dbc30f6f27303a50c90420bb862bb5c6fca3ce073af51060f958c031100d536773bf594fb6c4bd30dd6bfbb6ef37b1b73bbd8639c0717000000371e800000000000000000000000000000fffffd12431557001643727cb79bd7cb0ffcd35dee340100625630ad15bace55d78375b858006b02215473829367c910e2d0a6a473b4934e06db79fd48642896c3638cf008b1b5ec0132ef0332238cc8af63d5dc591dfa78578e239a7b7a9b8b9eb9dce194d6a6121c4a2c0e426e4cf50fdae37c1cf71bd6f472e0e42985182c8397f0f46d066dda1446726eebf544143c19dc18eaf1a776ed175390bde50c43c573646a94b4eaf407c3f521cc303585534e742fbe8126b375b9a3e69b941969ea2de952cc8a4ade02b7804e4116dbad9cecc26231985617aa27962ea5ef51cc021c239ce6e0662d01fd19941ef75ead0b92880b80cf2fc76a8f56667915fbd8eb0c894ee8cb87f40ff1867a1eb97b0869e258692f45b001759c0f41d1283251adc9dfe1d1a0e73209655d5d714f494ec56d6d43eafc34442f731d442aa63bf9d0230d5a68e215ef1d155f9ff8678f40f21e3af39dd1268c43061400205fd4b91ca2c467470a6f712ff295498b1fa4142025aaa8935f570b8512f4597838e8dc28cdb6ce0c1d1013127dc5ff708b011cd1bbfc58b2e671477a882a9f2418fd5a13d184722d83b5ba1dd06ea34ca33b8034bf5cffa5a9bcf9f014c9e03478ca92fede0929989c311d173f16be076938004b4826a3893c91c07c097b258ad491b2ebc8591a5f0db03211db7e23689f8f49f8784900f1abd195c5ae0143b83c2ea4f73f5873eee3f5c32ba0fee6093d30aca03ad93a8c06f148491f7654b89903e67cb04e18451a1682000200ee0000000005f5e100000000003b9aca0049d8735616f328843ef53b844fd429c2ff4e940901000000cf6f66cac9f03b13243262f365e44d00aae2eac80c6cd01fa05acac76829521ee4fc010b3056e0ea4da5886436010904659e61789e83a0dbad026af775eb0c192f6e0c159c3a47ede3daa77de6e63b60c9d74a6dedaef78120396f2512d113485bb3639524d1f211fdf5fc4fbb32e9eaf205a38626741762e9c2a23fbc4b32dc98db6e07d0f3c40deac704de64d0dfacb9844010dcfc666edad0b92f04ae6aead1b84b6f92a91b58001955074d28b0feb442551e6d179f8216a3730d642b1f7555f76f76974c"
            )
        );
        vm.stopPrank();
    }

    function makeDeposit(bool migrated) internal {
        // fork block: 44_681_944
        // tx: 0x334581b6e4253fc8f1f8d7bd050fa4fab80cf31da2016973ee0d07f64cd4dfd0
        // hex"2d3ca5b2f6253e11c3aeee418713c0ab60765b7fb0a54ebb70e8de164d658fb0047723eee68e39d3a45147db1b8f40765bf5a55304ec93e9a3c5c8192adf1cd1000000371f00000000000000000000000000000000000002540be40015a198886fbf27122b0aab780cee0698dde37b427ec117516a79e1fbaf0a868d068753683d57fea30e44a67f85d8d1718dd58a473f03f65abd54185e87a60984152a4b3ebc47711fe779e3b7d7431004d35e3e8b9cc517544eae4286988224602846984b0d3bb32e065537b3a1cd044e75ead418885ca7dc2f190896d74b5c3e121b87685e37dc018129bbfb84f7c63fdd791f3d08804c690d647f51be9cae881ff1a706fcb9ca05a51ad9e03bf3ae0f61a984d5026c24091e5ea02e006a0e9d1cd200fbae848fa04c8f8761d73860a7df35b22ab016fcb633584d1acbe4e1121d2f2870eb5cdf14d212b0c295109e04fff4977beb6c9d032aabddaf6f37e21f043cb380ad869e99c797d79e71318bda46805040223692354ede389eb6b2bfdd05b276db3031434dd359575959c045b045c473b40e6ed86176c54b4afa4693602c7f33e6c83cdc63e1d39bd6a09d1d692a8423a5cd5e72da579b55dbb086498210042e33ed02b50098f280c76edff2e9c020a821514de5f7fd058e93d28d792805e5ba498271e22790271a0b9741144b110165ad04454229613756979af47d5f16dbe25cc72418aae4eea6423e106d451d4bde0186dd43c45a5515f231351a4b0efeccc974f0abee9f4d576d4fc49818ccc4208a4d2bcac158ed5bde52a4bd262e9d11b27f8705802ceb869fa8f96132adf2f75a3b4eec602b701e256999aab007e8ba946bad4d9797fb5873d39a9725d607594153376124dace936efc5cd83c000300ee0000000005f5e1000000000064a467b639f0bd56c1439a22ee90b4972c16b7868d1619810100000018635a2048ca9eac95bcd68d8bcfe1918e50408c0e068febcbd4c6d427914c284d9b2b47ea0def251e379bafb27c9b3482c6b21da5468b5a372577ecf54484069fd0cbe6f8b9dc178657600dffc34add9f547ba2255e0b3a93fc9c5799fb09ee83fe0eae445bd0552d1e4758975fafa4880fb5d2ecb69bcca7075f47d60d2b926f6d22578247b9659e6a8cf3824e1db1071f5eb3564ab4546279b442912fcd90cf7578cc2c1684bbdb07232753e79be78e2e28d780def4ce296bcc2b7bd245470951aa0960902485314a928eda55143c77c8097c73b6337d091ff1e88d3001d3ecf8fc48c62fad75575455e21b02d27073c2b00425de31fe3cbe2978855f2c9bd923b239dba6"
        if (migrated) {
            deal(usdc_addr, address(0x39F0bD56c1439a22Ee90b4972c16b7868D161981), 10_100_000);
        } else {
            deal(bob_addr, address(0x39F0bD56c1439a22Ee90b4972c16b7868D161981), 10_100_000_000_000_000_000);
        }
        vm.startPrank(relayer_addr);
        address(pool).call(
            abi.encodePacked(
                pool.transact.selector,
                hex"2d3ca5b2f6253e11c3aeee418713c0ab60765b7fb0a54ebb70e8de164d658fb0047723eee68e39d3a45147db1b8f40765bf5a55304ec93e9a3c5c8192adf1cd1000000371f00000000000000000000000000000000000002540be40015a198886fbf27122b0aab780cee0698dde37b427ec117516a79e1fbaf0a868d068753683d57fea30e44a67f85d8d1718dd58a473f03f65abd54185e87a60984152a4b3ebc47711fe779e3b7d7431004d35e3e8b9cc517544eae4286988224602846984b0d3bb32e065537b3a1cd044e75ead418885ca7dc2f190896d74b5c3e121b87685e37dc018129bbfb84f7c63fdd791f3d08804c690d647f51be9cae881ff1a706fcb9ca05a51ad9e03bf3ae0f61a984d5026c24091e5ea02e006a0e9d1cd200fbae848fa04c8f8761d73860a7df35b22ab016fcb633584d1acbe4e1121d2f2870eb5cdf14d212b0c295109e04fff4977beb6c9d032aabddaf6f37e21f043cb380ad869e99c797d79e71318bda46805040223692354ede389eb6b2bfdd05b276db3031434dd359575959c045b045c473b40e6ed86176c54b4afa4693602c7f33e6c83cdc63e1d39bd6a09d1d692a8423a5cd5e72da579b55dbb086498210042e33ed02b50098f280c76edff2e9c020a821514de5f7fd058e93d28d792805e5ba498271e22790271a0b9741144b110165ad04454229613756979af47d5f16dbe25cc72418aae4eea6423e106d451d4bde0186dd43c45a5515f231351a4b0efeccc974f0abee9f4d576d4fc49818ccc4208a4d2bcac158ed5bde52a4bd262e9d11b27f8705802ceb869fa8f96132adf2f75a3b4eec602b701e256999aab007e8ba946bad4d9797fb5873d39a9725d607594153376124dace936efc5cd83c000300ee0000000005f5e1000000000064a467b639f0bd56c1439a22ee90b4972c16b7868d1619810100000018635a2048ca9eac95bcd68d8bcfe1918e50408c0e068febcbd4c6d427914c284d9b2b47ea0def251e379bafb27c9b3482c6b21da5468b5a372577ecf54484069fd0cbe6f8b9dc178657600dffc34add9f547ba2255e0b3a93fc9c5799fb09ee83fe0eae445bd0552d1e4758975fafa4880fb5d2ecb69bcca7075f47d60d2b926f6d22578247b9659e6a8cf3824e1db1071f5eb3564ab4546279b442912fcd90cf7578cc2c1684bbdb07232753e79be78e2e28d780def4ce296bcc2b7bd245470951aa0960902485314a928eda55143c77c8097c73b6337d091ff1e88d3001d3ecf8fc48c62fad75575455e21b02d27073c2b00425de31fe3cbe2978855f2c9bd923b239dba6"
            )
        );
        vm.stopPrank();
    }

    function makeDirectDeposit(bool migrated) internal returns (uint64 retval) {
        // fork block: 44_681_944
        // tx: 0x75503777b8ed6e5c533fef1f48f9fa8f1164961a4cca2ad64c23e05f73db3fe2
        address actor = address(0x39F0bD56c1439a22Ee90b4972c16b7868D161981);
        uint256 amount;
        address token_addr;
        string memory zk_addr = "HEicAjqEQpVwTULiWzBhhsW3vUmbyWxxqaHes6Dz1PSik3N1jWocg3qZbH43Qxc";
        if (migrated) {
            amount = 10_000_000;
            token_addr = usdc_addr;
        } else {
            amount = 10_000_000_000_000_000_000;
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
        (,,, retval) = abi.decode(entries[2].data, (address, bytes10, bytes32, uint64));
        vm.stopPrank();
    }

    function executeDirectDeposit() internal {
        // fork block: 44_681_944
        // tx: 0x04c75e1cef0134154cd6e894a645a7df5af26b243d7cd815e94495f9a4d3c818
        // hex"0388f862e9cbb39d23089a0cd3e46587e805432ce83df3ac401e6fa056faeef600000000000000000000000000000000000000000000000000000000000002602f4658f7d7bd89ae8c52b0d117179b0f37215d1b7a3f35e514c54152ff0742fc02e48b240c026e5e105f3650c49c69ad8bae5ffa6f8b35a5dbcd5ecedda8548407825f05adad3792426d21716aa1e0f57b565d6933010e94d14ac4163478fc0d247e5cd6e256f53b167af73c94bbf1ecd0a2dc1e97dc3e0827e0a2296101aff91b122391af6fe866b24e5117cf8ba961113db5b6ab9d34cf20b43eda7ed61f2812f6190fb2605a8ced4d275ad434f4c96129c2d497db1f2ae5c3a3330e8bf1372fd3d5d3812eb1518ef832a283c70de320f2a53b5d6541510ab51ac75ba87afe257f2f077ca573f162e6f0fbf3aa910c3ad8ef8623225039742486f674efef8a1cf9124d159921640b1a256b5c9b2c1d886e2d071e4957b5c93dd144cc6fcb041b959ecb7f33bbbec5a59950dabeca69a0ef42ea1504b99288abe8d3d7cb0cc0075c9c73d4c468887b3aa19838e9b2b2c3b20d89442553c7622a7d0dbaeff07203549de1ae39243acc4590d016b00b060d1fd8c9a3b069cac10ccc1198d3ec2404c63421b8c3d24ce9e1af75cdd79429bad242db325dcf46f607433647d5fa720418c17a5e418643a035102fb74bd02d8bd48a3d781825f4798645f600c9da2c249b1071f00c76e5da4010586469ad083bbcf6405ed50cd54df786b5ac3ae8c20fa78447b785e67386a11203c4a9d13d3c27f088f138fd826d12b12b5c79a0d92e606ac9d7664ef7fa589264cd823a20677322df0218ed5bfabfda75c6c49e2c0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001e"
        vm.startPrank(relayer_addr);
        address(pool).call(
            abi.encodePacked(
                pool.appendDirectDeposits.selector,
                hex"0388f862e9cbb39d23089a0cd3e46587e805432ce83df3ac401e6fa056faeef600000000000000000000000000000000000000000000000000000000000002602f4658f7d7bd89ae8c52b0d117179b0f37215d1b7a3f35e514c54152ff0742fc02e48b240c026e5e105f3650c49c69ad8bae5ffa6f8b35a5dbcd5ecedda8548407825f05adad3792426d21716aa1e0f57b565d6933010e94d14ac4163478fc0d247e5cd6e256f53b167af73c94bbf1ecd0a2dc1e97dc3e0827e0a2296101aff91b122391af6fe866b24e5117cf8ba961113db5b6ab9d34cf20b43eda7ed61f2812f6190fb2605a8ced4d275ad434f4c96129c2d497db1f2ae5c3a3330e8bf1372fd3d5d3812eb1518ef832a283c70de320f2a53b5d6541510ab51ac75ba87afe257f2f077ca573f162e6f0fbf3aa910c3ad8ef8623225039742486f674efef8a1cf9124d159921640b1a256b5c9b2c1d886e2d071e4957b5c93dd144cc6fcb041b959ecb7f33bbbec5a59950dabeca69a0ef42ea1504b99288abe8d3d7cb0cc0075c9c73d4c468887b3aa19838e9b2b2c3b20d89442553c7622a7d0dbaeff07203549de1ae39243acc4590d016b00b060d1fd8c9a3b069cac10ccc1198d3ec2404c63421b8c3d24ce9e1af75cdd79429bad242db325dcf46f607433647d5fa720418c17a5e418643a035102fb74bd02d8bd48a3d781825f4798645f600c9da2c249b1071f00c76e5da4010586469ad083bbcf6405ed50cd54df786b5ac3ae8c20fa78447b785e67386a11203c4a9d13d3c27f088f138fd826d12b12b5c79a0d92e606ac9d7664ef7fa589264cd823a20677322df0218ed5bfabfda75c6c49e2c0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001e"
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

    function makeDepositOutOfNomination() internal returns(bool status) {
        // fork block: 44_681_944
        // tx1: 0xc59e189535e5acf0ed3f7d75045da98dde7c20b8f89fe7b032e95937ac00eadd
        // hex"071cee7fa8f7a6b64cb49df9c236e38b0b92cbf20bf1385e78064f73384e5e3a123821ee60cca46e38b465b9d2b7ab1ed0a3dcf83d443823d6fbc92968bea0180000003720000000000000000000000000000000fffffffffa0a1f0019df9a23b0fc99e08108505b5eeee4937b27d995d130a1aeda5706dfeab059e2048e1f436cc89281746d65cd077694cc6f0e3bf2baed3631435070a12603b8e2125ee9e882adf70f286deae5d0e27de1b54bc32577545fa48ab8625842f051cb233ae2be16174c60dbc7e19ff2a25febd5c3b32e8aa233ef766592ec1b8221bc0597c9981d6ad04d19d2255f9369bad7d45920b796411281ef3ae523233aecdf04b9d4fac34da9e76ec2f443e74809796e9e82bc610b2eb7a463c972f7ec023f07308f5926e555d5c237bb18e7ed75164ec40cf20e761a8bfb966579713b949c2ac36820a12cef0d393e819de8d48f093e007a0951797a66add273f15e27d77001029b5e4b99d6c4fd16457924a2ba67d4572d769f212e6ac023db3d233dda02020646443589a5dee8e906423dd34ea834c34bf30f792694a44304de47dc55d71c4d3c70b10a8a36cf2f1796ce545facfcf2408b56765f0a1d9cb23f004f06e524b1f90169e5cab901146040f8dca88b44acde447eed2b3560048f7ab06d3d5b2ae781d8f026f9fe46b5ba3d35271749dbdf3c919d1cd36fc9bd217c2fcaa01c16c0883a0672a5003cb4afa37651633532243a03b8297d2f4b89413838ca68422cb117b74286575cbbb59b4c12b9f2ef1a125335b0925ff8fc4033faf368fedf20cf83ad2eddebea167699de6e5cb5a0ca91d4abb876fd14f928862385e8fdb00383bfaf9d35bc5ff1f3557ee38f22adbbe3a3ed24acba3530bc755d89d3fdb40001017e0000000005f5e10002000000c0004f9ced62cd61e90700d68e95033d1d8c0aee677fa4436712e8138cf61913ffa547642738fcc08b6f6de936883dfffa2e10cc8523caa37e2043056dc9d1196d7b35e2a16c1e8991578787181d060afcee1499cf592775fbe99c510775bf0aaa83e0249dbfc7ecdf248e5a8d4456010609a8a2ea63d9d292d67ddd91e0d639941ed5e462b738e23513a92233c59ba1ea6fe125564e6460f53904b60f2e284e1e8ee9eec63ff473f94292d09f11a88addf2c5ca07a9ddca37e45264278c9491cff73d389ecf3803a95df53ba6c8e32fe46c997aabd8a1744af3a4c60798d5c9a448d79501c92c66c58803a132d6abb93855b2a98119d0f8b29503a2ee43e879fa636fd2a54146c05a776253adfd70e36b0eb67f7f47eaa04221172c90b998e79ea2da2fb11545abe956eae715ba8814175187f1d8cdcb3ea2702655b556a86c82c5b8286c97c16d91f8cebb936af96233736291b07c4a319bdf0e5871649aac6c2d445f16054c30d182c46232197f8e111a"
        // tx2: 0xb941f2efdf5673b03206fcf43e9c82b91c5eef6106a5ecf0448ba01a40e0d515
        // hex"2b4d0a96168540f8671153e1533ca18aa44b8621c164bca3353b05862abf290726ee2cbcc282a72689e90e1cc83e2367d88c3d846b017c31d9c3ad08c2bbb56c0000003720800000000000000000000000000000000000024c38459c0270e2ca68e70320206d86b4bf3ed8d8d42bee867a146fd35dc30bac6c70f88c0cdcb38977d030a6fc54f4d7a6cfb471191b1434d526c9fd7f36a5eae082c6c806854a6bdf21d6b317e1ee25647ff247e7733befb4d4c39bf5d52107aae3c522234aebbc81b0bfc3e6c2056fd13e8ace561d8678ad12830ab3de96e9c7e66ec70bcc360b200b09fe393bf3aa4787b04c38a8aeb811cd942f61788e702ee827392382c541e31242c7fa73fadd9fbaa8177e3e3932e7eeeb97610c173a2afd458e26354d2c185fb394b6828591e6fceee9216234f944c14db491dcd66f4f75fe730fc6056aab8a0db70b2242cd8a3b0029bc2b62bd60dc821537cf40d319daf4d501413e4a29e7d7deb6e71f6cc998038f4c75cbfdeccfecb3401c12dbb4cfb00d171adade0021d0384fcd6150fdec5058b11e08a3e098213e19c4c643115d0bbd143860c33e008b412dbbaaa0d55772f615fa07da7d69c1b4b813d90c1469fc85118be3fe3ad64fcaf3fef954758b93b80188ddcc17da8193baf1edced4fbb7bc1f3e0caa34484b4ba80e874a9b8bd9529fda04b053836b5377bd393fab2447b90972fd3e90fff0fd05357ac785e8bce5f0eeafcaa121e98e8c95dc81056baba60decb84d799b5879c1115af265e807df5f9ba3a2e645b8077de86cc5a5b3f6452982bb5f4008d7fa4bd75638a4163b61df3bdeba3d871da3c0502e52009a14ff0ffa5ff687fa0d8b90e907656b92105beb0a7af026da3e86b37a40900911cee7000300ee0000000005f5e1000000000064a47a99e260b8e11bfb9ccc677d3cdf00f105c1e340fb8a010000001c2bbb824b7ba0ab413211118e67cbd95e61a889afa27d9af227dc8d27b8922ca386d187115e2d8418ff2b6b55063f7e57c9926fcecd1a133605c0515077d2116a59360d5660893d26ca28c38bf7de4b61dbde2bcddcedad9ac4521dd63ab686ea4f22b3b02e1f7b7b27c922eee1c5fcb9e14575c3e8a50713e79cc9ea61d277cb100eb0ad7faabbe4f9539a4404b87736d2ea47832d499564ff042f996840aa9563eb27e28f966d4f75a4ce1773ac01e3cd451255abb347b85c76d48b665f983f3bb862d4e6481b87e3a384ed48d3b9196a5013751cc3729c711509a9e1aba3c0ec92ae9ab95f806cda092161153fcdb0f8066b933a115af0b869ac8c32fd7161154dd69674"
        deal(usdc_addr, address(0xE260b8E11BFb9CCC677D3cdf00f105c1E340FB8a), 100_000_000);
        vm.startPrank(relayer_addr);
        // tx1 -- transfer
        address(pool).call(
            abi.encodePacked(
                pool.transact.selector,
                hex"071cee7fa8f7a6b64cb49df9c236e38b0b92cbf20bf1385e78064f73384e5e3a123821ee60cca46e38b465b9d2b7ab1ed0a3dcf83d443823d6fbc92968bea0180000003720000000000000000000000000000000fffffffffa0a1f0019df9a23b0fc99e08108505b5eeee4937b27d995d130a1aeda5706dfeab059e2048e1f436cc89281746d65cd077694cc6f0e3bf2baed3631435070a12603b8e2125ee9e882adf70f286deae5d0e27de1b54bc32577545fa48ab8625842f051cb233ae2be16174c60dbc7e19ff2a25febd5c3b32e8aa233ef766592ec1b8221bc0597c9981d6ad04d19d2255f9369bad7d45920b796411281ef3ae523233aecdf04b9d4fac34da9e76ec2f443e74809796e9e82bc610b2eb7a463c972f7ec023f07308f5926e555d5c237bb18e7ed75164ec40cf20e761a8bfb966579713b949c2ac36820a12cef0d393e819de8d48f093e007a0951797a66add273f15e27d77001029b5e4b99d6c4fd16457924a2ba67d4572d769f212e6ac023db3d233dda02020646443589a5dee8e906423dd34ea834c34bf30f792694a44304de47dc55d71c4d3c70b10a8a36cf2f1796ce545facfcf2408b56765f0a1d9cb23f004f06e524b1f90169e5cab901146040f8dca88b44acde447eed2b3560048f7ab06d3d5b2ae781d8f026f9fe46b5ba3d35271749dbdf3c919d1cd36fc9bd217c2fcaa01c16c0883a0672a5003cb4afa37651633532243a03b8297d2f4b89413838ca68422cb117b74286575cbbb59b4c12b9f2ef1a125335b0925ff8fc4033faf368fedf20cf83ad2eddebea167699de6e5cb5a0ca91d4abb876fd14f928862385e8fdb00383bfaf9d35bc5ff1f3557ee38f22adbbe3a3ed24acba3530bc755d89d3fdb40001017e0000000005f5e10002000000c0004f9ced62cd61e90700d68e95033d1d8c0aee677fa4436712e8138cf61913ffa547642738fcc08b6f6de936883dfffa2e10cc8523caa37e2043056dc9d1196d7b35e2a16c1e8991578787181d060afcee1499cf592775fbe99c510775bf0aaa83e0249dbfc7ecdf248e5a8d4456010609a8a2ea63d9d292d67ddd91e0d639941ed5e462b738e23513a92233c59ba1ea6fe125564e6460f53904b60f2e284e1e8ee9eec63ff473f94292d09f11a88addf2c5ca07a9ddca37e45264278c9491cff73d389ecf3803a95df53ba6c8e32fe46c997aabd8a1744af3a4c60798d5c9a448d79501c92c66c58803a132d6abb93855b2a98119d0f8b29503a2ee43e879fa636fd2a54146c05a776253adfd70e36b0eb67f7f47eaa04221172c90b998e79ea2da2fb11545abe956eae715ba8814175187f1d8cdcb3ea2702655b556a86c82c5b8286c97c16d91f8cebb936af96233736291b07c4a319bdf0e5871649aac6c2d445f16054c30d182c46232197f8e111a"
            )
        );
        // tx2 -- deposit
        (status, ) = address(pool).call(
            abi.encodePacked(
                pool.transact.selector,
                hex"2b4d0a96168540f8671153e1533ca18aa44b8621c164bca3353b05862abf290726ee2cbcc282a72689e90e1cc83e2367d88c3d846b017c31d9c3ad08c2bbb56c0000003720800000000000000000000000000000000000024c38459c0270e2ca68e70320206d86b4bf3ed8d8d42bee867a146fd35dc30bac6c70f88c0cdcb38977d030a6fc54f4d7a6cfb471191b1434d526c9fd7f36a5eae082c6c806854a6bdf21d6b317e1ee25647ff247e7733befb4d4c39bf5d52107aae3c522234aebbc81b0bfc3e6c2056fd13e8ace561d8678ad12830ab3de96e9c7e66ec70bcc360b200b09fe393bf3aa4787b04c38a8aeb811cd942f61788e702ee827392382c541e31242c7fa73fadd9fbaa8177e3e3932e7eeeb97610c173a2afd458e26354d2c185fb394b6828591e6fceee9216234f944c14db491dcd66f4f75fe730fc6056aab8a0db70b2242cd8a3b0029bc2b62bd60dc821537cf40d319daf4d501413e4a29e7d7deb6e71f6cc998038f4c75cbfdeccfecb3401c12dbb4cfb00d171adade0021d0384fcd6150fdec5058b11e08a3e098213e19c4c643115d0bbd143860c33e008b412dbbaaa0d55772f615fa07da7d69c1b4b813d90c1469fc85118be3fe3ad64fcaf3fef954758b93b80188ddcc17da8193baf1edced4fbb7bc1f3e0caa34484b4ba80e874a9b8bd9529fda04b053836b5377bd393fab2447b90972fd3e90fff0fd05357ac785e8bce5f0eeafcaa121e98e8c95dc81056baba60decb84d799b5879c1115af265e807df5f9ba3a2e645b8077de86cc5a5b3f6452982bb5f4008d7fa4bd75638a4163b61df3bdeba3d871da3c0502e52009a14ff0ffa5ff687fa0d8b90e907656b92105beb0a7af026da3e86b37a40900911cee7000300ee0000000005f5e1000000000064a47a99e260b8e11bfb9ccc677d3cdf00f105c1e340fb8a010000001c2bbb824b7ba0ab413211118e67cbd95e61a889afa27d9af227dc8d27b8922ca386d187115e2d8418ff2b6b55063f7e57c9926fcecd1a133605c0515077d2116a59360d5660893d26ca28c38bf7de4b61dbde2bcddcedad9ac4521dd63ab686ea4f22b3b02e1f7b7b27c922eee1c5fcb9e14575c3e8a50713e79cc9ea61d277cb100eb0ad7faabbe4f9539a4404b87736d2ea47832d499564ff042f996840aa9563eb27e28f966d4f75a4ce1773ac01e3cd451255abb347b85c76d48b665f983f3bb862d4e6481b87e3a384ed48d3b9196a5013751cc3729c711509a9e1aba3c0ec92ae9ab95f806cda092161153fcdb0f8066b933a115af0b869ac8c32fd7161154dd69674"
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
        address usdc_impl = deployCode("UChildAdministrableERC20.sol:UChildAdministrableERC20");
        bytes memory code = usdc_impl.code;
        vm.etch(EIP1967Proxy(payable(usdc_addr)).implementation(), code);
    }

    function run() external {
        if (block.number != 44_681_944) {
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
        require(
            prev_balance - new_balance == prev.fees / bobToUSDCshift,
            "Fees does not match"
        );

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
