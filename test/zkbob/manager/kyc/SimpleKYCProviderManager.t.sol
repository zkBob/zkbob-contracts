// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../../../shared/Env.t.sol";
import "../../../../src/zkbob/manager/kyc/SimpleKYCProviderManager.sol";
import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract SimpleKYCProviderManagerTest is Test {
    ERC721PresetMinterPauserAutoId nft;
    SimpleKYCProviderManager manager;

    uint8 internal constant TIER = 254;

    function setUp() public {
        nft = new ERC721PresetMinterPauserAutoId("Test NFT", "tNFT", "http://nft.url/");

        nft.mint(user1);

        manager = new SimpleKYCProviderManager(nft, TIER);
    }

    function testPassesKYC() public {
        assertEq(manager.passesKYC(user1), true);
        assertEq(manager.passesKYC(user2), false);
    }

    function testGetAssociatedLimitsTier() public {
        assertEq(manager.getAssociatedLimitsTier(user1, false), TIER);
        assertEq(manager.getAssociatedLimitsTier(user1, true), TIER);

        assertEq(manager.getAssociatedLimitsTier(user2, false), TIER);
        vm.expectRevert("KYCProviderManager: non-existing pool limits tier");
        manager.getAssociatedLimitsTier(user2, true);
    }
}
