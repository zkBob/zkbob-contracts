// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../proxy/EIP1967Admin.sol";

/**
 * @title Claimable
 */
contract Claimable is EIP1967Admin {
    /**
     * @dev Allows to transfer any locked token from this contract.
     * Callable only by the proxy admin.
     * @param _token address of the token contract, or 0x00..00 for transferring native coins.
     * @param _to locked tokens receiver address.
     */
    function claimTokens(address _token, address _to) external onlyAdmin {
        if (_token == address(0)) {
            payable(_to).transfer(address(this).balance);
        } else {
            uint256 balance = IERC20(_token).balanceOf(address(this));
            IERC20(_token).transfer(_to, balance);
        }
    }
}
