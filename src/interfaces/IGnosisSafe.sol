// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

interface IGnosisSafe {
    function isOwner(address owner) external view returns (bool);
}
