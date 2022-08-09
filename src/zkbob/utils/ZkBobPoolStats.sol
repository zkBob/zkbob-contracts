// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

abstract contract ZkBobPoolStats {
    // encoding scheme:
    // max_avg_tvl (56 bits)
    // max_count (32 bits)
    // tail_time_slot (24 bits)
    // head_time_slot (24 bits)
    // head_tvl_cum (56 bits)
    // head_tx_count (32 bits)
    // time_slot is calculated based on 1 hour of granularity
    // tvl is calculated based on 1e18 of balance granularity
    // tvl_cum is the cumulative sum of tvl over tx_count interactions
    // (head_time_slot - tail_time_slot) is at least 1 week
    // max_avg_tvl - max of ((head_tvl_cum - tail_tvl_cum) / (head_tx_count - tail_tx_count)) - max seen average tvl over period of at least 1 week
    uint256 private slot0;
    mapping(uint256 => uint256) private snapshots;

    function _decodeSlot0()
        private
        returns (uint56 maxTvl, uint32 maxCount, uint24 tailSlot, uint24 headSlot, uint88 cumTvl, uint32 count)
    {
        uint256 _slot0 = slot0;
        maxTvl = uint56((_slot0 >> 200) & type(uint56).max);
        maxCount = uint32((_slot0 >> 168) & type(uint32).max);
        tailSlot = uint24((_slot0 >> 144) & type(uint24).max);
        headSlot = uint24((_slot0 >> 120) & type(uint24).max);
        cumTvl = uint88((_slot0 >> 32) & type(uint88).max);
        count = uint32(_slot0 & type(uint32).max);
    }

    function _encodeSlot0(uint56 maxTvl, uint32 maxCount, uint24 tailSlot, uint24 headSlot, uint88 cumTvl, uint32 count)
        private
        pure
        returns (uint256 stat)
    {
        assembly {
            stat :=
                add(
                    add(add(add(add(shl(200, maxTvl), shl(168, maxCount)), shl(144, tailSlot)), shl(120, headSlot)), shl(32, cumTvl)),
                    count
                )
        }
    }

    function _decodeStat(uint256 _stat) private pure returns (uint24 slot, uint32 count, uint88 tvlCum) {
        slot = uint24((_stat >> 120) & type(uint24).max);
        count = uint32((_stat >> 88) & type(uint32).max);
        tvlCum = uint88(_stat & type(uint88).max);
    }

    function _encodeStat(uint24 slot, uint32 count, uint88 tvlCum) private pure returns (uint256 stat) {
        assembly {
            stat := add(add(shl(120, slot), shl(88, count)), tvlCum)
        }
    }

    function _updateStats() internal returns (uint56 weekMaxTvl, uint32 weekMaxCount, uint256 poolIndex) {
        (uint56 maxTvl, uint32 maxCount, uint24 tailSlot, uint24 headSlot, uint88 cumTvl, uint32 count) = _decodeSlot0();
        uint24 curSlot = uint24(block.timestamp / 1 hours);
        uint56 tvl = uint56(_tvl() / 1 ether);
        if (count > 0 && curSlot - tailSlot > 168) {
            (uint24 newTailSlot, uint32 tailCount, uint88 tailCumTvl) = _decodeStat(snapshots[tailSlot]);
            (tailSlot, snapshots[tailSlot]) = (newTailSlot, 0);
            uint32 txCount = count - tailCount;
            if (txCount > maxCount) {
                maxCount = txCount;
            }
            uint56 avgTvl = uint56((cumTvl - tailCumTvl) / txCount);
            if (avgTvl > maxTvl) {
                maxTvl = avgTvl;
            }
        }
        if (headSlot < curSlot) {
            snapshots[headSlot] = _encodeStat(curSlot, count, cumTvl);
        }
        slot0 = _encodeSlot0(maxTvl, maxCount, tailSlot, curSlot, cumTvl + tvl, count + 1);
        return (maxTvl, maxCount, count << 7);
    }

    function _tvl() internal view virtual returns (uint256);
}
