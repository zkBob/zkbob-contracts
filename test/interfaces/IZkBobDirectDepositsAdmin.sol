// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/interfaces/IZkBobDirectDeposits.sol";
import "../../src/interfaces/IZkBobDirectDepositQueue.sol";
import "../../src/interfaces/IZkBobDirectDepositsETH.sol";
import "../../src/interfaces/IOperatorManager.sol";

interface IZkBobDirectDepositsAdmin is IZkBobDirectDepositQueue, IZkBobDirectDepositsETH {
    function setOperatorManager(IOperatorManager _operatorManager) external;

    function setDirectDepositFee(uint64 _fee) external;

    function setDirectDepositTimeout(uint40 _timeout) external;
}
