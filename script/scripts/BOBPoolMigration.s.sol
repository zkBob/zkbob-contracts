// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "./Env.s.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPoolBOB.sol";
import "../../src/zkbob/ZkBobPoolUSDCMigrated.sol";
import "../../src/zkbob/utils/ZkBobAccounting.sol";

contract BOBPoolMigration is Script, StdCheats {
    ZkBobPoolBOB pool = ZkBobPoolBOB(0x72e6B59D4a90ab232e55D4BB7ed2dD17494D62fB);
    address bob_addr = address(0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B);
    address usdc_addr = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    address relayer_addr = address(0xc2c4AD59B78F4A0aFD0CDB8133E640Db08Fa5b90);

    struct VerificationValues {
        uint256 withdrawalDiff;
        uint256 depositDiff;
        uint256 fees;
        ZkBobAccounting.Limits limits;
    }

    function migrate() internal {
        ITransferVerifier transferVerifier = pool.transfer_verifier();
        ITreeVerifier treeVerifier = pool.tree_verifier();
        IBatchDepositVerifier batchDepositVerifier = pool.batch_deposit_verifier();
        uint256 pool_id = pool.pool_id();
        IZkBobDirectDepositQueue queue_proxy = pool.direct_deposit_queue();

        vm.startPrank(deployer);
        ZkBobPoolUSDCMigrated poolImpl = new ZkBobPoolUSDCMigrated(
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
    }

    function makeFeesWithdrawal() internal {
        vm.startPrank(relayer_addr);
        pool.withdrawFee(relayer_addr, relayer_addr);
        vm.stopPrank();
    }

    function makeWithdrawal() internal {
        vm.startPrank(relayer_addr);
        //tx: 0x69969a1aed22acd3a06c06dd4654f002a993bcfd0d628ad066ef89d85bfb8aa2
        address(pool).call(
            abi.encodePacked(
                pool.transact.selector,
                hex"0af0ba93499da982aafafc850d6c35fe6fd15db390f07461ee78345457e4fd48220ea886e45a936b82474fb8bbd5c5f14652938eb5915f574103b73f4ef195eb00000036c6000000000000000000000000000000fffffd9ba1d2e3002d9aa0ffb81ccf13cbad806be76d6336ac1202e096ad3f15474968ab08623da504f9195c7688ae1d308416725f08fe9752b62727b9c334eae81eccb9b1e2285f179f72f5555bfed598da848daccd761e47eef7db0945d4898436098831b8e73b1f1f711791869a21dbfb022ab3fff41f0719599ef95845ff0dd606315d14bc1b0fe999af6214ace7bb9bd30150e3eb0dbbf0c5c312ff4422af46d28e9c5958471fb1d827409b82f189cf823d204644a0d85f024636885745af0cb31310d5b9ed0c599aeb182c51a35653f6b3c173bc91d19320ee23756dbbbf08fa9190c6f912259285ad43815b545b925b9202e423f25a78dda06e59397523ece66b62c002340371d18fc9a18930259993970b7bfc2414fc05c01d7768d1e09616859bd446eb27c085e8a4ce80e2b14d717a3f5ff2be3bf00aa460e94868b684183220a3f0060b9f8410edbaada1dcae6886185a5fb2cf937e0de83873c8bb5b955f1670f3a4137fae74466eaea68edb9707dcc15c3a70942314636f602d32d08922350b2d712e71cc822ad9e7c2cdc6596724c79eda765fdb92a38fb91d7c79cbf69b3c86a12a10de43132eeca95ad19747e1da460c7b859c11e46c92f71a86fbfccb6623531f2060e1130466f163b0b454201ddb1c57109c7d93dcfa1bd40a1e0bf20518730e9d565a1ba64076055e55d5ac5be40fd1a2dfe63ea5784ddcc7562fbc26f05e03f6806cb22d02993c15fcc561128ff9db2bdcde284b32c9c336a77d0e9992e3000200ee0000000005f5e100000000000000000047c2149ac0a70b74dd6f5538bf112adea54eee93010000002ad7407ba35babd44adea482ef8003cc2bef8b7830b4b2230f3e39857ea7302a629dc70590bcbe1ff6b3d8c2bccfbbefd4d693eafa4a64f653613abf8161752cea6294e95defd64b79a494404ba1b6dce7dd55059c247b6fc2331e9b0e633df84db2a3eed1c3b073803fc2e9959d1e75cfbf30760f3e56d5a1ec931ddc7ebc88732a1224debc8bdd2994297a3aa8d4bc519bdfb2a58c4cf97ab73fdd6785a8bf54bafc5e1037c08d912c9ac2f1ab8a3a9961af03d641ec470966bfa3cd33a331a3270385ab31"
            )
        );
        vm.stopPrank();
    }

    function makeDeposit(bool migrated) internal {
        if (migrated) {
            deal(usdc_addr, address(0x9692b44a40CC8e17fFe70b8F51Cb106D9eff6500), 1_004_100_000);
        } else {
            deal(bob_addr, address(0x9692b44a40CC8e17fFe70b8F51Cb106D9eff6500), 1_004_100_000_000_000_000_000);
        }
        vm.startPrank(relayer_addr);
        // tx: 0xe445be8dbf55a1ada80b3d6181bd444a78779b31136f5cbfa0a733a1b7836171
        address(pool).call(
            abi.encodePacked(
                pool.transact.selector,
                hex"17478505eec4af5fab22891ee2aeaeb78069bee458a1a95b3e718bba914cec3406fb19c7e7d9a0f070923d97190fa9910276432505a7918d2837d753ae54030900000036c6800000000000000000000000000000000000e9c31038002177f434a11ccc625e4fcf2b1e9819e6b3d45eb4ba96556c18e197882009572b1bc633a5046c65fc7e4dea6e6077fe2624ea2820dec30d64ebacbcffe5d9c0ab14a226ec0e42c645eae7381583aa2c71954584bd8616ccc76f5bbd49a342df7f013b1906e2231803750a9dad65f8abaaafc7024958626d1839aaf352ca6195ca1a63ec26e019916accd11a9f2a86688bc6026097951509cd1a25059cb99297641faa959c168b9e07a3483d907088a09e982d9e196124c529cbe2dbc8230a4a7b2755798cdf1561ff4ca9c4437ab397f6f2978c24ae42d5db5e4664e2d19e7fef0a125ff732b80692e363aab98f987b4fbbdf8741f15882fa97f585a401e0bc272bab67c26008f4157f64934e9bd46e34b03f1dcae33f2ad71ddafee1feeaebe52bf73d032716d7d8e8ff1c7df70913f2183efef2552df504489e70e9bd83ea2425aa3f5caf6f056afed782ebcab4cdc9520d59f95112a417280342cda315c09015bb77f1994493855cec2bf61986e7c69bed2a247902332ef59bb5a38d1e3f40207c2e4daea47b1b1dbf5c7e28339057a33171a2b3f6b3fe8c296a47bdadde451217d2533ee983e463bafe4be3fc523ed0d3f4c964ccdc818710bd967c8d08a10963ec4bb9a7b05727b0f7a151cbdadbe6774d2154b73427d4647776d6fd501b182ac8bf75d6cc9f02ff68533adc0148c18ae2419059dbc14f071341a8ab2d5221d8b88ad540d11bb2380067192438c362d5c1515cca333a6a6c825bf5233106000300ee0000000005f5e1000000000064a2c2899692b44a40cc8e17ffe70b8f51cb106d9eff650001000000ace3c3d6aa293ff60ee64baf1eb49b86cfab172c5cda8c145614863fc020831c59490f63987e443a4879963277867e334da1dd1bfc710c610b897000f3e194281d52483017ceb7c06ddec1c84ff3e46dea3fb1130be53aa29ec317da90ed93fd878898c9fa0ebedb4f1a610aaedd4c45d690a9ec8575489ee5100499471bc9acbff222a005d4ffae216c4b14bcdec24eefec00f70c9b602842b193ce31c2f46ff8d41e16da6d8a902a9625cb3c11ae016db2d3be7e258ea049dec148addd5174d5b0b8210cc00c84948b304b7118cb63259f8f911716f9f4f543ea4070d5f42d695265c76bd6b8959069d76987539aee7efc39d881611ac7e97e329f639c127628fb2b8d22ab"
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

    function getVerificationValues() internal returns (VerificationValues memory) {
        uint256 snapshot = vm.snapshot();

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
        if (block.number != 44_632_406) {
            return;
        }

        uint256 bobToUSDCshift = 10 ** (IERC20Metadata(bob_addr).decimals() - IERC20Metadata(usdc_addr).decimals());

        VerificationValues memory prev = getVerificationValues();

        migrate();

        require(pool.denominator() == (1 << 255) | 1000, "Incorrect denominator");

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
