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

    function makeDirectDeposit(bool migrated) internal returns(uint64 retval) {
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
        (, , , retval) = abi.decode(entries[2].data, (address, bytes10, bytes32, uint64));
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
        require(
            dd_in == prev.ddIn,
            "Input DD value does not match"
        );

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
        makeFeesWithdrawal();
        require(
            prev_balance - IERC20(usdc_addr).balanceOf(address(pool)) == prev.fees / bobToUSDCshift,
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
    }
}
