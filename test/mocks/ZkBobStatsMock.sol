// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../src/zkbob/utils/ZkBobPoolStats.sol";

contract ZkBobStatsMock is ZkBobPoolStats {
    uint256 tvl;
    uint32 public weekMaxTvl;
    uint32 public weekMaxCount;
    uint256 public poolIndex;

    function _tvl() internal view override returns (uint256) {
        return tvl;
    }

    function slot0() external view returns (bytes32 res) {
        assembly {
            res := sload(0)
        }
    }

    function transact(uint256 _newTvl) external {
        (weekMaxTvl, weekMaxCount, poolIndex) = _updateStats();
        tvl = _newTvl;
    }
}
