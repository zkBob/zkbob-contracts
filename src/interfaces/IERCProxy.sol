// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

interface IERCProxy {
    function implementation() external view returns (address codeAddr);
}
