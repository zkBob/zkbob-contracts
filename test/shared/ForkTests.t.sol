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
        forkRpcUrl = vm.envOr("FORK_RPC_URL_MAINNET", forkRpcUrlMainnet);
        forkBlock = vm.envOr("FORK_BLOCK_NUMBER_MAINNET", forkBlockMainnet);
    }
}

abstract contract AbstractPolygonForkTest is AbstractForkTest {
    constructor() {
        forkRpcUrl = vm.envOr("FORK_RPC_URL_POLYGON", forkRpcUrlPolygon);
        forkBlock = vm.envOr("FORK_BLOCK_NUMBER_POLYGON", forkBlockPolygon);
    }
}

abstract contract AbstractOptimismForkTest is AbstractForkTest {
    constructor() {
        forkRpcUrl = vm.envOr("FORK_RPC_URL_OPTIMISM", forkRpcUrlOptimism);
        forkBlock = vm.envOr("FORK_BLOCK_NUMBER_OPTIMISM", forkBlockOptimism);
    }
}
