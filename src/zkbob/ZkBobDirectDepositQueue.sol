// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./ZkBobDirectDepositQueueAbs.sol";
import "./ZkBobDirectDepositDTO.sol";

/**
 * @title ZkBobDirectDepositQueue
 * Queue for zkBob direct deposits.
 */
contract ZkBobDirectDepositQueue is ZkBobDirectDepositQueueAbs, ZkBobDirectDepositDTO {
    constructor(
        address _pool,
        address _token,
        uint256 _denominator
    )
        ZkBobDirectDepositQueueAbs(_pool, _token, _denominator)
    {}
}
