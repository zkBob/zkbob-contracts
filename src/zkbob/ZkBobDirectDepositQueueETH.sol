// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ZkBobDirectDepositQueueAbs.sol";
import "./ZkBobDirectDepositETHMixin.sol";
import "./ZkBobDirectDepositDTO.sol";

/**
 * @title ZkBobDirectDepositQueueETH
 * Queue for zkBob ETH direct deposits.
 */
contract ZkBobDirectDepositQueueETH is ZkBobDirectDepositQueueAbs, ZkBobDirectDepositETHMixin, ZkBobDirectDepositDTO {
    constructor(
        address _pool,
        address _token,
        uint256 _denominator
    )
        ZkBobDirectDepositQueueAbs(_pool, _token, _denominator)
    {}
}
