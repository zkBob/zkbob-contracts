// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "./Env.t.sol";

abstract contract AbstractForkTest is Test {
    string forkRpcUrl;
    uint256 forkBlock;
}

abstract contract AbstractMainnetForkTest is AbstractForkTest {
    constructor() {
        forkRpcUrl = forkRpcUrlMainnet;
        forkBlock = forkBlockMainnet;
    }
}

abstract contract AbstractPolygonForkTest is AbstractForkTest {
    constructor() {
        forkRpcUrl = forkRpcUrlPolygon;
        forkBlock = forkBlockPolygon;
    }
}

abstract contract AbstractOptimismForkTest is AbstractForkTest {
    constructor() {
        forkRpcUrl = forkRpcUrlOptimism;
        forkBlock = forkBlockOptimism;
    }
}
