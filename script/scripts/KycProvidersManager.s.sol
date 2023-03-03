// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../../src/zkbob/manager/kyc/SimpleKYCProviderManager.sol";

contract DeploySimpleKYCProviderManager is Script {
    IERC721 private constant nft = IERC721(0x6137B159970e8c9C26f12235Fb6609CfBC6EE357);

    function run() external {
        vm.startBroadcast();

        SimpleKYCProviderManager mgr = new SimpleKYCProviderManager(nft, 254);

        vm.stopBroadcast();

        // discover proper address from transactions on https://sepolia.etherscan.io/address/0xc19397cccb7eddfb83533cfde6d21efc2eb860ef
        (bool kyced, uint8 tier) = mgr.getIfKYCpassedAndTier(0x84E94F8032b3F9fEc34EE05F192Ad57003337988);
        require(kyced, "User has no KYC");
        require(tier == 254, "Tier is not set");

        console2.log("KYCProviderManager:", address(mgr));
    }
}
