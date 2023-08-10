// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

interface IATokenVault {
    // solhint-disable-next-line func-name-mixedcase
    function UNDERLYING() external view returns (address token);

    function initialize(
        address owner,
        uint256 initialFee,
        string memory shareName,
        string memory shareSymbol,
        uint256 initialLockDeposit
    )
        external;

    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    function previewDeposit(uint256 assets) external view returns (uint256 shares);
}
