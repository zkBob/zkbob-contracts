// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../src/zkbob/periphery/ZkBobPay.sol";
import "../../src/proxy/EIP1967Proxy.sol";

contract DeployZkBobPay is Script {
    function run() external {
        vm.startBroadcast();

        address token = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        address queue = address(0x668c5286eAD26fAC5fa944887F9D2F20f7DDF289);
        address permit2 = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        address lifiRouter1 = address(0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE);
        address lifiRouter2 = address(0x9b11bc9FAc17c058CAB6286b0c785bE6a65492EF);
        address feeReceiver = address(0x39F0bD56c1439a22Ee90b4972c16b7868D161981);

        ZkBobPay pay = new ZkBobPay(token, queue, permit2);
        EIP1967Proxy proxy =
            new EIP1967Proxy(tx.origin, address(pay), abi.encodeWithSelector(ZkBobPay.initialize.selector));
        pay = ZkBobPay(address(proxy));

        pay.updateFeeReceiver(feeReceiver);
        pay.updateRouter(lifiRouter1, true);
        pay.updateRouter(lifiRouter2, true);

        vm.stopBroadcast();

        console2.log("ZkBobPay:", address(pay));
    }
}
