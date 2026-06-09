// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

interface IUSDC {
    function isBlacklisted(address _account) external view returns (bool);
}
