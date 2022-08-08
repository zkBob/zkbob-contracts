// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

abstract contract ZkBobPoolStats {
    // encoding scheme:
    // max_avg_tvl (32 bits)
    // tail (112 bits) = time_slot (24 bits), tx_count (32 bits), tvl_cum (56 bits)
    // head (112 bits) = time_slot (24 bits), tx_count (32 bits), tvl_cum (56 bits))
    // time_slot is calculated based on 1 hour of granularity
    // tvl is calculated based on 100 * 1e8 balance granularity
    // tvl_cum is the cumulative sum of tvl over tx_count interactions (allowed to overflow)
    // (head.time_slot - tail.time_slot) is at least 1 week
    // (head.tx_count - tail.tx_count) never decreases
    // max_avg_tvl - max of ((head.tvl_cum - tail.tvl_cum) / (head.tx_count - tail.tx_count)) - max seen average tvl over period of at least 1 week
    uint256 private slot0;
    // single linked list from tail to head
    mapping(uint256 => uint256) private next;

    function _decodeSlot0() private returns (uint32 maxTvl, uint112 tail, uint112 head) {
        uint256 _slot0 = slot0;
        maxTvl = uint32(_slot0 >> 224);
        tail = uint112((_slot0 >> 112) & type(uint112).max);
        head = uint112(_slot0 & type(uint112).max);
    }

    function _encodeSlot0(uint32 maxTvl, uint112 tail, uint112 head) private pure returns (uint256 stat) {
        assembly {
            stat := add(add(shl(224, maxTvl), shl(112, tail)), head)
        }
    }

    function _decodeStat(uint112 _stat) private pure returns (uint24 slot, uint32 count, uint56 tvlCum) {
        slot = uint24(_stat >> 88);
        count = uint32(_stat >> 56);
        tvlCum = uint56(_stat & type(uint56).max);
    }

    function _encodeStat(uint24 slot, uint32 count, uint56 tvlCum) private pure returns (uint112 stat) {
        assembly {
            stat := add(add(shl(88, slot), shl(56, count)), tvlCum)
        }
    }

    function _updateStats() internal returns (uint32 weekMaxTvl, uint32 weekMaxCount, uint256 poolIndex) {
        (uint32 maxTvl, uint112 tail, uint112 head) = _decodeSlot0();
        (uint24 tailSlot, uint32 tailCount, uint56 tailTvlCum) = _decodeStat(tail);
        (uint24 headSlot, uint32 headCount, uint56 headTvlCum) = _decodeStat(head);
        uint24 curSlot = uint24(block.timestamp / 1 hours);
        uint32 tvl = uint32(_tvl() / 100 ether);
        unchecked {
            poolIndex = headCount * 128;
            headTvlCum = (headTvlCum + tvl) & type(uint56).max;
        }
        headCount++;

        unchecked {
            uint32 avgTvl = uint32((uint256(headTvlCum) - uint256(tailTvlCum)) / uint256((headCount - tailCount)));
            if (avgTvl > maxTvl) {
                maxTvl = avgTvl;
            }
        }

        uint112 newHead = _encodeStat(curSlot, headCount, headTvlCum);
        if (headSlot - tailSlot >= (1 weeks / 1 hours)) {
            (tail, next[uint256(tail)]) = (uint112(next[uint256(tail)]), 0);
        }
        next[uint256(head)] = uint256(newHead);
        slot0 = _encodeSlot0(maxTvl, tail, newHead);

        return (maxTvl, headCount - tailCount, poolIndex);
    }

    function _tvl() internal view virtual returns (uint256);
}
