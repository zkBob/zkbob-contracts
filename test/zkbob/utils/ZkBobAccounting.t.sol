// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../../shared/Env.t.sol";
import "../../mocks/ZkBobAccountingMock.sol";
import "../../../src/zkbob/manager/kyc/SimpleKYCProviderManager.sol";
import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract ZkBobAccountingTest is Test {
    ZkBobAccountingMock pool;

    uint8 internal constant TIER_FOR_KYC = 254;

    function setUp() public {
        pool = new ZkBobAccountingMock();

        pool.setLimits(0, 1000 ether, 1000 ether, 1000 ether, 1000 ether, 1000 ether, 0, 0);

        vm.warp(1000 weeks);
    }

    function testBasicStats() public {
        emit log_bytes32(pool.slot0());

        // baseline (100 BOB tvl ~13.8 days)
        pool.transact(int256(100 ether));
        vm.warp(block.timestamp + 20 minutes);
        for (uint256 i = 1; i < 999; i++) {
            pool.transact(0);
            vm.warp(block.timestamp + 20 minutes);
        }
        assertEq(pool.weekMaxTvl(), 100);
        assertEq(pool.weekMaxCount(), 504);
        assertEq(pool.txCount(), 998);
        emit log_bytes32(pool.slot0());

        // 100 -> 300 BOB tvl change for ~2.8 days
        for (uint256 i = 0; i < 201; i++) {
            pool.transact(1 ether);
            vm.warp(block.timestamp + 20 minutes);
        }
        assertEq(pool.weekMaxTvl(), 138);
        assertEq(pool.weekMaxCount(), 504);
        assertEq(pool.txCount(), 1199);
        emit log_bytes32(pool.slot0());

        // 300 BOB tvl for ~1.4 days
        for (uint256 i = 0; i < 204; i++) {
            pool.transact(0);
            vm.warp(block.timestamp + 10 minutes);
        }
        assertEq(pool.weekMaxTvl(), 199);
        assertEq(pool.weekMaxCount(), 603);
        assertEq(pool.txCount(), 1403);
        emit log_bytes32(pool.slot0());

        // back to 100 BOB tvl
        pool.transact(int256(-200 ether));
        vm.warp(block.timestamp + 30 minutes);
        for (uint256 i = 1; i < 1000; i++) {
            pool.transact(0);
            vm.warp(block.timestamp + 30 minutes);
        }
        assertEq(pool.weekMaxTvl(), 215);
        assertEq(pool.weekMaxCount(), 606);
        assertEq(pool.txCount(), 2403);
        emit log_bytes32(pool.slot0());
    }

    function testSparseIntervals() public {
        emit log_bytes32(pool.slot0());

        // baseline (100 BOB tvl ~13.8 days)
        pool.transact(int256(100 ether));
        vm.warp(block.timestamp + 20 minutes);
        for (uint256 i = 1; i < 999; i++) {
            pool.transact(0);
            vm.warp(block.timestamp + 20 minutes);
        }
        for (uint256 i = 1; i <= 10; i++) {
            for (uint256 j = 0; j < 10; j++) {
                pool.transact(i == 1 && j == 0 ? int256(100 ether) : int256(0));
            }
            vm.warp(block.timestamp + i * 1 hours);
        }
        for (uint256 i = 0; i < 1000; i++) {
            pool.transact(i == 0 ? int256(-100 ether) : int256(0));
            vm.warp(block.timestamp + 30 minutes);
        }
        assertEq(pool.weekMaxTvl(), 130);
        assertEq(pool.weekMaxCount(), 523);
        assertEq(pool.txCount(), 2098);
        emit log_bytes32(pool.slot0());
    }

    function testLaggingBehind() public {
        // baseline (100 BOB tvl ~13.8 days)
        pool.transact(int256(100 ether));
        vm.warp(block.timestamp + 20 minutes);
        for (uint256 i = 1; i < 999; i++) {
            pool.transact(0);
            vm.warp(block.timestamp + 20 minutes);
        }

        // 200 BOB tvl for 10 days
        pool.transact(int256(100 ether));
        vm.warp(block.timestamp + 6 hours);
        for (uint256 i = 1; i < 40; i++) {
            pool.transact(0);
            vm.warp(block.timestamp + 6 hours);
        }
        // since tail pointer didn't catch up, max tvl is still less than 200 BOB
        assertEq(pool.weekMaxTvl(), 108);
        assertEq(pool.weekMaxCount(), 504);
        assertEq(pool.txCount(), 1038);

        // 200 BOB tvl for 7 days
        for (uint256 i = 0; i < 168; i++) {
            pool.transact(0);
            vm.warp(block.timestamp + 1 hours);
        }
        // since tail pointer didn't catch up, max tvl is still less than 200 BOB
        assertEq(pool.weekMaxTvl(), 200);
        assertEq(pool.weekMaxCount(), 504);
        assertEq(pool.txCount(), 1206);
    }

    function testDepositCap() public {
        pool.setLimits(0, 1000 ether, 500 ether, 500 ether, 300 ether, 100 ether, 0, 0);

        vm.expectRevert("ZkBobAccounting: single deposit cap exceeded");
        pool.transact(200 ether);
        pool.transact(100 ether);
        pool.transact(50 ether);
    }

    function testDailyUserDepositCap() public {
        pool.setLimits(0, 1000 ether, 500 ether, 500 ether, 200 ether, 100 ether, 0, 0);

        pool.transact(100 ether);
        pool.transact(100 ether);
        vm.expectRevert("ZkBobAccounting: daily user deposit cap exceeded");
        pool.transact(100 ether);
    }

    function testDailyDepositCap() public {
        pool.setLimits(0, 1000 ether, 500 ether, 500 ether, 200 ether, 100 ether, 0, 0);

        pool.transact(100 ether);
        pool.transact(100 ether);

        vm.startPrank(user1);
        pool.transact(100 ether);
        pool.transact(100 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        pool.transact(100 ether);
        vm.expectRevert("ZkBobAccounting: daily deposit cap exceeded");
        pool.transact(100 ether);
        vm.stopPrank();
    }

    function testTvlCap() public {
        pool.setLimits(0, 1000 ether, 500 ether, 500 ether, 200 ether, 100 ether, 0, 0);

        for (uint256 i = 0; i < 10; i++) {
            pool.transact(100 ether);
            vm.warp(block.timestamp + 1 days);
        }

        vm.expectRevert("ZkBobAccounting: tvl cap exceeded");
        pool.transact(100 ether);
    }

    function testDailyUserDepositCapReset() public {
        pool.setLimits(0, 10000 ether, 500 ether, 500 ether, 200 ether, 100 ether, 0, 0);

        for (uint256 i = 0; i < 5; i++) {
            pool.transact(100 ether);
            pool.transact(100 ether);
            vm.expectRevert("ZkBobAccounting: daily user deposit cap exceeded");
            pool.transact(100 ether);

            vm.warp(block.timestamp + 1 days);
        }
    }

    function testDailyDepositCapReset() public {
        pool.setLimits(0, 10000 ether, 500 ether, 500 ether, 300 ether, 150 ether, 0, 0);

        for (uint256 i = 0; i < 5; i++) {
            pool.transact(150 ether);
            vm.prank(user1);
            pool.transact(150 ether);
            vm.prank(user2);
            pool.transact(150 ether);

            vm.expectRevert("ZkBobAccounting: daily deposit cap exceeded");
            pool.transact(150 ether);
            vm.prank(user1);
            vm.expectRevert("ZkBobAccounting: daily deposit cap exceeded");
            pool.transact(150 ether);
            vm.prank(user2);
            vm.expectRevert("ZkBobAccounting: daily deposit cap exceeded");
            pool.transact(150 ether);

            vm.warp(block.timestamp + 1 days);
        }
    }

    function testDailyWithdrawalCap() public {
        pool.setLimits(0, 1000 ether, 500 ether, 300 ether, 200 ether, 100 ether, 0, 0);

        for (uint256 i = 0; i < 10; i++) {
            pool.transact(100 ether);
            vm.warp(block.timestamp + 1 days);
        }

        vm.startPrank(user1);
        pool.transact(-100 ether);
        pool.transact(-100 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        pool.transact(-100 ether);
        vm.expectRevert("ZkBobAccounting: daily withdrawal cap exceeded");
        pool.transact(-100 ether);
        vm.stopPrank();
    }

    function testDailyWithdrawalCapReset() public {
        pool.setLimits(0, 10000 ether, 500 ether, 500 ether, 300 ether, 100 ether, 0, 0);

        for (uint256 i = 0; i < 100; i++) {
            pool.transact(100 ether);
            vm.warp(block.timestamp + 1 days);
        }

        for (uint256 i = 0; i < 5; i++) {
            pool.transact(-150 ether);
            vm.prank(user1);
            pool.transact(-150 ether);
            vm.prank(user2);
            pool.transact(-150 ether);

            vm.expectRevert("ZkBobAccounting: daily withdrawal cap exceeded");
            pool.transact(-150 ether);
            vm.prank(user1);
            vm.expectRevert("ZkBobAccounting: daily withdrawal cap exceeded");
            pool.transact(-150 ether);
            vm.prank(user2);
            vm.expectRevert("ZkBobAccounting: daily withdrawal cap exceeded");
            pool.transact(-150 ether);

            vm.warp(block.timestamp + 1 days);
        }
    }

    function testGetLimitsFor() public {
        pool.setLimits(0, 10000 ether, 500 ether, 400 ether, 300 ether, 150 ether, 0, 0);

        ZkBobAccounting.Limits memory limits1;
        ZkBobAccounting.Limits memory limits2;

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 10000 gwei);
        assertEq(limits1.tvl, 0 gwei);
        assertEq(limits1.dailyDepositCap, 500 gwei);
        assertEq(limits1.dailyDepositCapUsage, 0 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits1.dailyUserDepositCap, 300 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 0 gwei);
        assertEq(limits1.depositCap, 150 gwei);

        vm.startPrank(user1);
        pool.transact(50 ether);
        pool.transact(70 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        pool.transact(100 ether);
        pool.transact(-10 ether);
        vm.stopPrank();

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 10000 gwei);
        assertEq(limits1.tvl, 210 gwei);
        assertEq(limits1.dailyDepositCap, 500 gwei);
        assertEq(limits1.dailyDepositCapUsage, 220 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 10 gwei);
        assertEq(limits1.dailyUserDepositCap, 300 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 120 gwei);
        assertEq(limits1.depositCap, 150 gwei);

        limits2 = pool.getLimitsFor(user2);
        assertEq(limits2.tvlCap, 10000 gwei);
        assertEq(limits2.tvl, 210 gwei);
        assertEq(limits2.dailyDepositCap, 500 gwei);
        assertEq(limits2.dailyDepositCapUsage, 220 gwei);
        assertEq(limits2.dailyWithdrawalCap, 400 gwei);
        assertEq(limits2.dailyWithdrawalCapUsage, 10 gwei);
        assertEq(limits2.dailyUserDepositCap, 300 gwei);
        assertEq(limits2.dailyUserDepositCapUsage, 100 gwei);
        assertEq(limits2.depositCap, 150 gwei);

        vm.warp(block.timestamp + 1 days);

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 10000 gwei);
        assertEq(limits1.tvl, 210 gwei);
        assertEq(limits1.dailyDepositCap, 500 gwei);
        assertEq(limits1.dailyDepositCapUsage, 0 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits1.dailyUserDepositCap, 300 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 0 gwei);
        assertEq(limits1.depositCap, 150 gwei);

        limits2 = pool.getLimitsFor(user2);
        assertEq(limits2.tvlCap, 10000 gwei);
        assertEq(limits2.tvl, 210 gwei);
        assertEq(limits2.dailyDepositCap, 500 gwei);
        assertEq(limits2.dailyDepositCapUsage, 0 gwei);
        assertEq(limits2.dailyWithdrawalCap, 400 gwei);
        assertEq(limits2.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits2.dailyUserDepositCap, 300 gwei);
        assertEq(limits2.dailyUserDepositCapUsage, 0 gwei);
        assertEq(limits2.depositCap, 150 gwei);
    }

    function testPoolDailyLimitsReset() public {
        pool.setLimits(0, 10000 ether, 500 ether, 400 ether, 300 ether, 150 ether, 0, 0);

        ZkBobAccounting.Limits memory limits1;

        vm.startPrank(user1);
        pool.transact(70 ether);
        pool.transact(-50 ether);
        vm.stopPrank();

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 10000 gwei);
        assertEq(limits1.tvl, 20 gwei);
        assertEq(limits1.dailyDepositCap, 500 gwei);
        assertEq(limits1.dailyDepositCapUsage, 70 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 50 gwei);
        assertEq(limits1.dailyUserDepositCap, 300 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 70 gwei);
        assertEq(limits1.depositCap, 150 gwei);

        vm.warp(block.timestamp + 1 days);

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 10000 gwei);
        assertEq(limits1.tvl, 20 gwei);
        assertEq(limits1.dailyDepositCap, 500 gwei);
        assertEq(limits1.dailyDepositCapUsage, 0 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits1.dailyUserDepositCap, 300 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 0 gwei);
        assertEq(limits1.depositCap, 150 gwei);

        uint256 sid1 = vm.snapshot();
        uint256 sid2 = vm.snapshot();

        // deposit on a new day should reset daily deposit and withdrawal limits
        vm.prank(user1);
        pool.transact(100 ether);

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 10000 gwei);
        assertEq(limits1.tvl, 120 gwei);
        assertEq(limits1.dailyDepositCap, 500 gwei);
        assertEq(limits1.dailyDepositCapUsage, 100 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits1.dailyUserDepositCap, 300 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 100 gwei);
        assertEq(limits1.depositCap, 150 gwei);

        vm.revertTo(sid2);

        // withdrawal on a new day should reset daily deposit and withdrawal limits
        vm.prank(user1);
        pool.transact(-10 ether);

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 10000 gwei);
        assertEq(limits1.tvl, 10 gwei);
        assertEq(limits1.dailyDepositCap, 500 gwei);
        assertEq(limits1.dailyDepositCapUsage, 0 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 10 gwei);
        assertEq(limits1.dailyUserDepositCap, 300 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 0 gwei);
        assertEq(limits1.depositCap, 150 gwei);

        vm.revertTo(sid1);

        // private transfer on a new day should reset daily deposit and withdrawal limits
        vm.prank(user1);
        pool.transact(0 ether);

        limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 10000 gwei);
        assertEq(limits1.tvl, 20 gwei);
        assertEq(limits1.dailyDepositCap, 500 gwei);
        assertEq(limits1.dailyDepositCapUsage, 0 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits1.dailyUserDepositCap, 300 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 0 gwei);
        assertEq(limits1.depositCap, 150 gwei);
    }

    function testPoolLimitsTiers() public {
        pool.setLimits(0, 600 ether, 200 ether, 400 ether, 180 ether, 150 ether, 0, 0);
        pool.setLimits(1, 10000 ether, 1000 ether, 800 ether, 600 ether, 300 ether, 0, 0);

        pool.setUserTier(1, user2);
        vm.expectRevert("ZkBobAccounting: non-existing pool limits tier");
        pool.setUserTier(2, user3);
        pool.setUserTier(255, user3);

        // TVL == 0, Tier 0 (0/200, 0/400), Tier 1 (0/1000, 0/800), User 1 (0/180), User2 (0/600)

        vm.prank(user1);
        pool.transact(100 ether);
        vm.prank(user2);
        pool.transact(100 ether);
        vm.prank(user3);
        vm.expectRevert("ZkBobAccounting: single deposit cap exceeded");
        pool.transact(100 ether);

        // TVL == 200, Tier 0 (100/200, 0/400), Tier 1 (100/1000, 0/800), User 1 (100/180), User2 (100/600)

        vm.prank(user1);
        vm.expectRevert("ZkBobAccounting: single deposit cap exceeded");
        pool.transact(200 ether);
        vm.prank(user2);
        pool.transact(200 ether);

        // TVL == 400, Tier 0 (100/200, 0/400), Tier 1 (300/1000, 0/800), User 1 (100/180), User2 (300/600)

        vm.prank(user1);
        vm.expectRevert("ZkBobAccounting: daily user deposit cap exceeded");
        pool.transact(150 ether);
        vm.prank(user1);
        vm.expectRevert("ZkBobAccounting: daily user deposit cap exceeded");
        pool.transact(90 ether);
        vm.prank(user4);
        vm.expectRevert("ZkBobAccounting: daily deposit cap exceeded");
        pool.transact(150 ether);
        vm.prank(user2);
        pool.transact(150 ether);

        // TVL == 550, Tier 0 (100/200, 0/400), Tier 1 (450/1000, 0/800), User 1 (100/180), User2 (450/600)

        vm.prank(user1);
        vm.expectRevert("ZkBobAccounting: tvl cap exceeded");
        pool.transact(150 ether);
        vm.prank(user2);
        pool.transact(150 ether);

        // TVL == 700, Tier 0 (100/200, 0/400), Tier 1 (600/1000, 0/800), User 1 (100/180), User2 (600/600)

        ZkBobAccounting.Limits memory limits1 = pool.getLimitsFor(user1);
        assertEq(limits1.tvlCap, 600 gwei);
        assertEq(limits1.tvl, 700 gwei);
        assertEq(limits1.dailyDepositCap, 200 gwei);
        assertEq(limits1.dailyDepositCapUsage, 100 gwei);
        assertEq(limits1.dailyWithdrawalCap, 400 gwei);
        assertEq(limits1.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits1.dailyUserDepositCap, 180 gwei);
        assertEq(limits1.dailyUserDepositCapUsage, 100 gwei);
        assertEq(limits1.depositCap, 150 gwei);
        assertEq(limits1.tier, 0);

        ZkBobAccounting.Limits memory limits2 = pool.getLimitsFor(user2);
        assertEq(limits2.tvlCap, 10000 gwei);
        assertEq(limits2.tvl, 700 gwei);
        assertEq(limits2.dailyDepositCap, 1000 gwei);
        assertEq(limits2.dailyDepositCapUsage, 600 gwei);
        assertEq(limits2.dailyWithdrawalCap, 800 gwei);
        assertEq(limits2.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits2.dailyUserDepositCap, 600 gwei);
        assertEq(limits2.dailyUserDepositCapUsage, 600 gwei);
        assertEq(limits2.depositCap, 300 gwei);
        assertEq(limits2.tier, 1);

        ZkBobAccounting.Limits memory limits3 = pool.getLimitsFor(user3);
        assertEq(limits3.tvlCap, 0 gwei);
        assertEq(limits3.tvl, 700 gwei);
        assertEq(limits3.dailyDepositCap, 0 gwei);
        assertEq(limits3.dailyDepositCapUsage, 0 gwei);
        assertEq(limits3.dailyWithdrawalCap, 0 gwei);
        assertEq(limits3.dailyWithdrawalCapUsage, 0 gwei);
        assertEq(limits3.dailyUserDepositCap, 0 gwei);
        assertEq(limits3.dailyUserDepositCapUsage, 0 gwei);
        assertEq(limits3.depositCap, 0 gwei);
        assertEq(limits3.tier, 255);
    }

    function _setKYCPorviderManager() internal returns (SimpleKYCProviderManager) {
        ERC721PresetMinterPauserAutoId nft = new ERC721PresetMinterPauserAutoId("Test NFT", "tNFT", "http://nft.url/");

        SimpleKYCProviderManager manager = new SimpleKYCProviderManager(nft, TIER_FOR_KYC);
        pool.setKycProvidersManager(manager);

        return manager;
    }

    function _mintNFT(ERC721PresetMinterPauserAutoId _nft, address _user) internal returns (uint256) {
        uint256 tokenId = 0;
        vm.recordLogs();
        _nft.mint(_user);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("Transfer(address,address,uint256)")) {
                tokenId = uint256(entries[i].topics[3]);
                emit log_uint(tokenId);
                break;
            }
            // fail test if the event is not found
            assertLt(i, entries.length - 1);
        }
        return tokenId;
    }

    function testSetKycProvidersManager() public {
        address manager = address(_setKYCPorviderManager());
        assertEq(address(pool.kycProvidersManager()), manager);

        vm.expectRevert("ZkBobPool: manager is zero address");
        pool.setKycProvidersManager(SimpleKYCProviderManager(address(0)));
    }

    function testGetLimitsForTiersWithKYCProvider() public {
        ZkBobAccounting.Limits memory limits;

        SimpleKYCProviderManager manager = _setKYCPorviderManager();
        ERC721PresetMinterPauserAutoId nft = ERC721PresetMinterPauserAutoId(address(manager.NFT()));

        //                            dailyDepositCap                  depositCap
        //                            |          dailyWithdrawalCap    |          dailyUserDirectDepositCap
        //                tvlCap      |          |          dailyUserDepositCap   |  directDepositCap
        pool.setLimits(0, 1000 ether, 500 ether, 400 ether, 300 ether, 150 ether, 0, 0);

        //                           dailyDepositCap                  depositCap
        //                           |          dailyWithdrawalCap    |          dailyUserDirectDepositCap
        //                tvlCap     |          |          dailyUserDepositCap   |  directDepositCap
        pool.setLimits(1, 900 ether, 400 ether, 300 ether, 200 ether, 100 ether, 0, 0);

        //                                      dailyDepositCap                  depositCap
        //                                      |          dailyWithdrawalCap    |         dailyUserDirectDepositCap
        //                           tvlCap     |          |          dailyUserDepositCap  |  directDepositCap
        pool.setLimits(TIER_FOR_KYC, 500 ether, 250 ether, 200 ether, 150 ether, 75 ether, 0, 0);

        // Test 1: Limits for the user passed KYC but without a dedicated tier
        uint256 tokenId = _mintNFT(nft, user3);

        limits = pool.getLimitsFor(user3);
        assertEq(limits.tvlCap, 500 gwei);
        assertEq(limits.dailyDepositCap, 250 gwei);
        assertEq(limits.dailyWithdrawalCap, 200 gwei);
        assertEq(limits.dailyUserDepositCap, 150 gwei);
        assertEq(limits.depositCap, 75 gwei);

        // Test 2: Limits for the user passed KYC and with a dedicated tier
        uint256 unused_tokenId = _mintNFT(nft, user2);
        pool.setUserTier(1, user2);

        limits = pool.getLimitsFor(user2);
        assertEq(limits.tvlCap, 900 gwei);
        assertEq(limits.dailyDepositCap, 400 gwei);
        assertEq(limits.dailyWithdrawalCap, 300 gwei);
        assertEq(limits.dailyUserDepositCap, 200 gwei);
        assertEq(limits.depositCap, 100 gwei);

        // Test 3: Limits for the user passed KYC initially and revoked later
        vm.startPrank(user3);
        nft.burn(tokenId);
        vm.stopPrank();

        limits = pool.getLimitsFor(user3);
        assertEq(limits.tvlCap, 1000 gwei);
        assertEq(limits.dailyDepositCap, 500 gwei);
        assertEq(limits.dailyWithdrawalCap, 400 gwei);
        assertEq(limits.dailyUserDepositCap, 300 gwei);
        assertEq(limits.depositCap, 150 gwei);
    }

    function testPoolLimitsTooLarge() public {
        vm.expectRevert("ZkBobAccounting: tvl cap too large");
        pool.setLimits(0, 1e18 ether, 500 ether, 400 ether, 300 ether, 150 ether, 0, 0);
        vm.expectRevert("ZkBobAccounting: daily deposit cap too large");
        pool.setLimits(0, 1e16 ether, 1e10 ether, 400 ether, 300 ether, 150 ether, 0, 0);
        vm.expectRevert("ZkBobAccounting: daily withdrawal cap too large");
        pool.setLimits(0, 1e16 ether, 500 ether, 1e10 ether, 300 ether, 150 ether, 0, 0);
    }
}
