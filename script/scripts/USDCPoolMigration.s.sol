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
import "../../src/zkbob/ZkBobPoolUSDC.sol";
import "../../src/zkbob/ZkBobPoolUSDCMigrated.sol";
import "../../src/zkbob/utils/ZkBobAccounting.sol";
import "../../src/zkbob/ZkBobDirectDepositQueue.sol";
import "../../src/utils/UniswapV3Seller.sol";

contract USDCPoolMigration is Script, StdCheats {
    ZkBobPoolUSDC pool = ZkBobPoolUSDC(0x72e6B59D4a90ab232e55D4BB7ed2dD17494D62fB);
    ZkBobDirectDepositQueue queue_proxy = ZkBobDirectDepositQueue(0x668c5286eAD26fAC5fa944887F9D2F20f7DDF289);
    address usdc_addr = address(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359);
    address old_usdc_addr = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    address relayer_addr = address(0xc2c4AD59B78F4A0aFD0CDB8133E640Db08Fa5b90);
    address upgradeability_owner = address(0x9eC9D8B2Ff9b9f93D7eD3362D714d751B4f8982a);

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

        vm.startPrank(upgradeability_owner);
        EIP1967Proxy(payable(address(pool))).upgradeTo(address(poolImpl));
        EIP1967Proxy(payable(address(queue_proxy))).upgradeTo(address(queueImpl));
        pool.setTokenSeller(address(seller));
        vm.stopPrank();

        deal(usdc_addr, deployer, 1_000_000 * 1e6);
        vm.startPrank(deployer);
        IERC20(usdc_addr).approve(address(pool), type(uint256).max);
        ZkBobPoolUSDCMigrated(address(pool)).fillMigrationOrder(IERC20(old_usdc_addr).balanceOf(address(pool)));
        IERC20(usdc_addr).approve(address(pool), 0);
        vm.stopPrank();
    }

    function makeFeesWithdrawal() internal {
        vm.startPrank(relayer_addr);
        pool.withdrawFee(relayer_addr, relayer_addr);
        vm.stopPrank();
    }

    function makeWithdrawal() internal {
        // fork block: 49_471_423
        // tx: 0x109ca771a9ed1b4eb0bfdf3ae8c7d9e11e44c491e6cb37be06c98fb1cf9507f2
        // hex"af9890830c885f0b70295f19a9178672a6d8dbd405a02d570e67c2d871eaf673432d71cf086c2f2778aca0e410f7e3a56eb4cd377df0998a38270552f52dbe2b2bb2718d0000005395800000000000000000000000000000fffffff455ceab0000332ede35d248e15d2cae7fea3aaa43971b399d062192bcfa786cb7291cf33910a343e6f4496d71a053cae1c17db1cd7ca20a0cb47e64fd546928b12c89d79509d668a6a28b9ded425356aea2bf549c7d985042ee6c4bd90c58579792cbd4b61cfb614995620da51d503e3f67aa0301ebb8fd66ff3f01a3e03a2c4dd690834e0bfe340ef9cf738675b677c739c3cb0181eb7e3dd4eab0218983dc78f96ff7921775fcd62da14359b5b6dc64ac8b3ed5907ac9f8b31ab0a92df58888ec8879f900ed757e5993b9ab8ba131a864503b16f2fdeba2602caf389d51167f3f93d08325db239932fbb72db465094405ded9681379fe303224dc47a01e835cd766987c0a9cfcc7437b80572f0f9b10d87d9d758ad3a8758d7f9e5fdea10a0097d4da4a2ae9214372777d6b63fc4c6194a1849a07b8e2223cb347346f6d311d3f949ec201e00289fb4193d1cd01fde433c7c3a28f11297bec92abdafb29654fc87627262d7c4866e3bffe22caa2d03710c76beb9c6683d44ed2d4881ae267ccbd0ae2c125dfe06054c01499a65ebc5c0c1caf732cd72c2da8392336c6bf8bc5d6e7e1032d266f71474b4253b449a6b36428b8fac7fd8c4cff4d6407ee8204dd20a32e5f1865a7ec2e749dc8c8aac389b783c2b5efdeac897c9dc2a0d5eebd0fd3d2c07012e4b73daac5c78d679b68d707145a0b18215c108e54d162f93423676329bc7e17a8db534bde60e6bcb12b3fdcf3224fec7e66af57b149e5595acf075269d9d0000200ee0000000005f5e100000000000000000055271b22104f510380fe181d1094d79b2533a0a1010000006b4e269b0d1f8611a89bf8ee1fae4c1f3dd3e56ec0f15894936bbb3e728c2d06fff04cb834dc46df0b902b841b0bb77987f86d4474a97d3711de3e47f34d470739e7104ba5878997a336d66015d162b4b8338c817f40a238b353856b58bd481443e1733c515fee79c4c524ae5b288149afa1d62191674779e14e7ea4535ce4ca77353c8e0dfe60f1fbf0714bba5904ce5ee4a9275438f43e14154fd687ec5b128c0abe04b681e1ccd4108b9db8a780da8516827aa43bebf15d4ad1b4b1d693740c5b45e89c11"
        vm.prank(relayer_addr);
        (bool status,) = address(pool).call(
            hex"af9890830c885f0b70295f19a9178672a6d8dbd405a02d570e67c2d871eaf673432d71cf086c2f2778aca0e410f7e3a56eb4cd377df0998a38270552f52dbe2b2bb2718d0000005395800000000000000000000000000000fffffff455ceab0000332ede35d248e15d2cae7fea3aaa43971b399d062192bcfa786cb7291cf33910a343e6f4496d71a053cae1c17db1cd7ca20a0cb47e64fd546928b12c89d79509d668a6a28b9ded425356aea2bf549c7d985042ee6c4bd90c58579792cbd4b61cfb614995620da51d503e3f67aa0301ebb8fd66ff3f01a3e03a2c4dd690834e0bfe340ef9cf738675b677c739c3cb0181eb7e3dd4eab0218983dc78f96ff7921775fcd62da14359b5b6dc64ac8b3ed5907ac9f8b31ab0a92df58888ec8879f900ed757e5993b9ab8ba131a864503b16f2fdeba2602caf389d51167f3f93d08325db239932fbb72db465094405ded9681379fe303224dc47a01e835cd766987c0a9cfcc7437b80572f0f9b10d87d9d758ad3a8758d7f9e5fdea10a0097d4da4a2ae9214372777d6b63fc4c6194a1849a07b8e2223cb347346f6d311d3f949ec201e00289fb4193d1cd01fde433c7c3a28f11297bec92abdafb29654fc87627262d7c4866e3bffe22caa2d03710c76beb9c6683d44ed2d4881ae267ccbd0ae2c125dfe06054c01499a65ebc5c0c1caf732cd72c2da8392336c6bf8bc5d6e7e1032d266f71474b4253b449a6b36428b8fac7fd8c4cff4d6407ee8204dd20a32e5f1865a7ec2e749dc8c8aac389b783c2b5efdeac897c9dc2a0d5eebd0fd3d2c07012e4b73daac5c78d679b68d707145a0b18215c108e54d162f93423676329bc7e17a8db534bde60e6bcb12b3fdcf3224fec7e66af57b149e5595acf075269d9d0000200ee0000000005f5e100000000000000000055271b22104f510380fe181d1094d79b2533a0a1010000006b4e269b0d1f8611a89bf8ee1fae4c1f3dd3e56ec0f15894936bbb3e728c2d06fff04cb834dc46df0b902b841b0bb77987f86d4474a97d3711de3e47f34d470739e7104ba5878997a336d66015d162b4b8338c817f40a238b353856b58bd481443e1733c515fee79c4c524ae5b288149afa1d62191674779e14e7ea4535ce4ca77353c8e0dfe60f1fbf0714bba5904ce5ee4a9275438f43e14154fd687ec5b128c0abe04b681e1ccd4108b9db8a780da8516827aa43bebf15d4ad1b4b1d693740c5b45e89c11"
        );
        require(status);
    }

    function makeDeposit(bool migrated) internal {
        // fork block: 49_471_423
        // tx: 0xfd5baa34d590341c827c54686222720303c433e8b8ce1545f0a47172b237f6b2
        // hex"af9890830f156d795413e7277d3877b7de3e0366d38ce180139d77fa08055a4df1399d291bf459f1b2516e16d7c70f43def42277780322de5736c2c3e907dc46fce2e0f80000005396000000000000000000000000000000000003fddda224002a4cef9540983a6906c0f9f2e55780e84268bf12e99daaaf2d5ffa479754757b04226ea83bfa9e334fd6be0f389df9f8ffe9840b023a11cd045224bae4df20831b05cfd6339fbe49946de134e453abb8ab3b8ba17c1f897a40607865b6f6dfee141fbfa6658b67eae61e0607aec8dd33b0bd9dcdbd2b525223cbe88f7e285dd4131af0b31544b305f77a190b1989411b3263aedb14be73c33e13b9c290f9b3bc093ae6e9cd6d2f270fb416786c2a584c065beffd07ef75711fd54bb6f9c316d52e2b70b04185bc84c9a709751f3f19a4904808d64211d80662761bdce58d6ac9046508dfcb43db28c9f3994248ed435c3a9872dcc5797e773527c3b406dd8cdd0df3e95fb2999441cfedf2d14f594b4dc392f5eed01eee63ae20500b729d33670805a4f2f1674c1083e7bdd1c7f5bf38a3fd4fadfa301a8988fae9b57d224db90214812e3156bd3dd7752a8daed4ea8d7ee1b9a10e335cfb8b547369825574980de4c1942ba2b92ca480054fbd689cd48c39c3261cddaa03808e409da99f95ec2853341945e2eb51e0967d9b422060ea1daceb3fb9216ae62edfea4f21bf83d2077a348f55e46e60dd879fdfa3332e8c6e371c089dd2fe8206c9740a688f32d714877f4c65253c2abe35adeed01f455479480551b547a1d9d4d454af84c17cd01e4392100110cf9c2bdf8f5009193344471b2bab5a75db6690d536e24aba7e331a2a5609fa6fcc564b93d6776af00021237181ab130777670fdf63ae60a39051000300ee0000000005f5e10000000000654467e577e8699959cbd08e57edc6608db8d1340a2fc5d301000000d344eee17b68ae13db486937e54dca3f3d570f3e6faf1ac4de613091811e9c2d5b050e00d7bc0cae2f1ada7cff4197d30635fb5761a9f6fad1d6711846a55221af7a4b72a923653cd22cd3d944da4c09cd2fc5110e08a9f8849305c343dbfc5d176817f5601dbfb9890430bc6202642822d91517047e2992825a49f243cbfcc2b4490d3204560f419dda99f98bee55a333aeaf87cc55ad537fb1d6ff035109765d39d5e7731ca2a5f683a5f4e755950d09786d82e4e4a450d7e8ae1a46a14914644d0ec3618d3ff3d129c828dca4320c6421b5201e7f38933756165056563d5a8070a278f63487273a5e329b2a852fde5988eaef5feb5c3d4ab1a1a5536181d4bc61a3bb56c9"
        if (migrated) {
            vm.mockCall(
                address(0x01),
                hex"7be4247cf1c06fc0f5ebbe6167bb293bfca85391f9e6dd9615784b4670620036",
                abi.encode(0x77e8699959cbD08e57EDc6608dB8D1340a2FC5d3)
            );
            deal(usdc_addr, 0x77e8699959cbD08e57EDc6608dB8D1340a2FC5d3, 4_388.98 * 1e6);
        } else {
            deal(old_usdc_addr, 0x77e8699959cbD08e57EDc6608dB8D1340a2FC5d3, 4_388.98 * 1e6);
        }
        vm.prank(relayer_addr);
        (bool status,) = address(pool).call(
            hex"af9890830f156d795413e7277d3877b7de3e0366d38ce180139d77fa08055a4df1399d291bf459f1b2516e16d7c70f43def42277780322de5736c2c3e907dc46fce2e0f80000005396000000000000000000000000000000000003fddda224002a4cef9540983a6906c0f9f2e55780e84268bf12e99daaaf2d5ffa479754757b04226ea83bfa9e334fd6be0f389df9f8ffe9840b023a11cd045224bae4df20831b05cfd6339fbe49946de134e453abb8ab3b8ba17c1f897a40607865b6f6dfee141fbfa6658b67eae61e0607aec8dd33b0bd9dcdbd2b525223cbe88f7e285dd4131af0b31544b305f77a190b1989411b3263aedb14be73c33e13b9c290f9b3bc093ae6e9cd6d2f270fb416786c2a584c065beffd07ef75711fd54bb6f9c316d52e2b70b04185bc84c9a709751f3f19a4904808d64211d80662761bdce58d6ac9046508dfcb43db28c9f3994248ed435c3a9872dcc5797e773527c3b406dd8cdd0df3e95fb2999441cfedf2d14f594b4dc392f5eed01eee63ae20500b729d33670805a4f2f1674c1083e7bdd1c7f5bf38a3fd4fadfa301a8988fae9b57d224db90214812e3156bd3dd7752a8daed4ea8d7ee1b9a10e335cfb8b547369825574980de4c1942ba2b92ca480054fbd689cd48c39c3261cddaa03808e409da99f95ec2853341945e2eb51e0967d9b422060ea1daceb3fb9216ae62edfea4f21bf83d2077a348f55e46e60dd879fdfa3332e8c6e371c089dd2fe8206c9740a688f32d714877f4c65253c2abe35adeed01f455479480551b547a1d9d4d454af84c17cd01e4392100110cf9c2bdf8f5009193344471b2bab5a75db6690d536e24aba7e331a2a5609fa6fcc564b93d6776af00021237181ab130777670fdf63ae60a39051000300ee0000000005f5e10000000000654467e577e8699959cbd08e57edc6608db8d1340a2fc5d301000000d344eee17b68ae13db486937e54dca3f3d570f3e6faf1ac4de613091811e9c2d5b050e00d7bc0cae2f1ada7cff4197d30635fb5761a9f6fad1d6711846a55221af7a4b72a923653cd22cd3d944da4c09cd2fc5110e08a9f8849305c343dbfc5d176817f5601dbfb9890430bc6202642822d91517047e2992825a49f243cbfcc2b4490d3204560f419dda99f98bee55a333aeaf87cc55ad537fb1d6ff035109765d39d5e7731ca2a5f683a5f4e755950d09786d82e4e4a450d7e8ae1a46a14914644d0ec3618d3ff3d129c828dca4320c6421b5201e7f38933756165056563d5a8070a278f63487273a5e329b2a852fde5988eaef5feb5c3d4ab1a1a5536181d4bc61a3bb56c9"
        );
        require(status);
    }

    function makeDirectDeposit(bool migrated) internal returns (uint256 dd_index, uint256 retval) {
        // fork block: 49_471_423
        address actor = deployer;
        uint256 amount = 4_000_000;
        address token_addr = migrated ? usdc_addr : old_usdc_addr;
        string memory zk_addr = "M18WEorQwwYFv5DEeRTCNARLLN1Ud37DKUupQVrGBforX7C8XZchfGcgH1fLXEx";
        deal(token_addr, actor, amount);
        vm.startPrank(actor);
        IERC20(token_addr).approve(address(queue_proxy), amount);
        vm.recordLogs();
        queue_proxy.directDeposit(actor, amount, zk_addr);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        uint8 log_index = 255;
        for (uint8 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == 0xcde1b1a4bd18b6b8ddb2a80b1fce51c4eee01748267692ac6bc0770a84bc6c58) {
                log_index = i;
                dd_index = uint256(entries[i].topics[2]);
                break;
            }
        }
        (,,, retval) = abi.decode(entries[log_index].data, (address, bytes10, bytes32, uint256));
        vm.stopPrank();
    }

    function executeDirectDeposit(uint256[] memory _indices) internal {
        vm.mockCall(address(0x08), "", abi.encode(true));
        vm.startPrank(relayer_addr);
        (bool status,) = address(pool).call(
            abi.encodeWithSelector(
                pool.appendDirectDeposits.selector, _randFR(), _indices, _randFR(), _randProof(), _randProof()
            )
        );
        require(status);
        vm.stopPrank();
        vm.clearMockedCalls();
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

        (uint256 dd_index, uint256 prev_dd_in) = makeDirectDeposit(false);

        uint256 prev_balance = IERC20(old_usdc_addr).balanceOf(address(pool));
        makeWithdrawal();
        uint256 new_balance = IERC20(old_usdc_addr).balanceOf(address(pool));
        uint256 prev_withdrawal_diff = prev_balance - new_balance;

        prev_balance = new_balance;
        makeDeposit(false);
        new_balance = IERC20(old_usdc_addr).balanceOf(address(pool));
        uint256 prev_deposit_diff = new_balance - prev_balance;

        prev_balance = new_balance;
        uint256[] memory dd_indices = new uint256[](1);
        dd_indices[0] = dd_index;
        executeDirectDeposit(dd_indices);
        new_balance = IERC20(old_usdc_addr).balanceOf(address(pool));
        uint256 prev_dd_out_diff = new_balance - prev_balance;

        prev_balance = new_balance;
        makeFeesWithdrawal();
        uint256 prev_fees = prev_balance - IERC20(old_usdc_addr).balanceOf(address(pool));

        setLimits(relayer_addr, 1e12);
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

    function run() external {
        if (block.number != 49_471_423) {
            return;
        }

        VerificationValues memory prev = getVerificationValues();

        migrate();

        require(IERC20(old_usdc_addr).balanceOf(address(pool)) == 0, "Invalid USDC balance");
        require(IERC20(usdc_addr).balanceOf(address(pool)) > 0, "Invalid USDC.e balance");

        require(pool.denominator() == (1 << 255) | 1000, "Incorrect denominator");

        (uint256 dd_index, uint256 dd_in) = makeDirectDeposit(true);
        require(dd_in == prev.ddIn, "Input DD value does not match");

        uint256 prev_balance = IERC20(usdc_addr).balanceOf(address(pool));
        makeWithdrawal();
        uint256 new_balance = IERC20(usdc_addr).balanceOf(address(pool));
        require(prev_balance - new_balance == prev.withdrawalDiff, "Incorrect balance");

        prev_balance = new_balance;
        makeDeposit(true);
        new_balance = IERC20(usdc_addr).balanceOf(address(pool));
        require(new_balance - prev_balance == prev.depositDiff, "Incorrect balance");

        prev_balance = new_balance;
        uint256[] memory dd_indices = new uint256[](1);
        dd_indices[0] = dd_index;
        executeDirectDeposit(dd_indices);
        new_balance = IERC20(usdc_addr).balanceOf(address(pool));
        require(new_balance - prev_balance == prev.ddOutDiff, "Incorrect balance");

        prev_balance = new_balance;
        makeFeesWithdrawal();
        new_balance = IERC20(usdc_addr).balanceOf(address(pool));
        require(prev_balance - new_balance == prev.fees, "Fees does not match");

        setLimits(relayer_addr, 1e12);
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

    function _randFR() internal returns (uint256) {
        return uint256(keccak256(abi.encode(gasleft())))
            % 21888242871839275222246405745257275088696311157297823662689037894645226208583;
    }

    function _randProof() internal returns (uint256[8] memory) {
        return [_randFR(), _randFR(), _randFR(), _randFR(), _randFR(), _randFR(), _randFR(), _randFR()];
    }
}
