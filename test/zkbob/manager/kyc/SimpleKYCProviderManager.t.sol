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

    function testGetIfKYCpassedAndTier() public {
        (bool passed, uint8 tier) = manager.getIfKYCpassedAndTier(user1);
        assertEq(passed, true);
        assertEq(tier, TIER);

        (passed, tier) = manager.getIfKYCpassedAndTier(user2);
        assertEq(passed, false);
        assertEq(tier, 0);
    }
}
