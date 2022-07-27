// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "./proxy/EIP1967Admin.sol";

/**
 * @title Blacklistable
 */
contract Blacklistable is EIP1967Admin {
    address public blacklister;
    mapping(address => bool) internal blacklisted;

    event Blacklisted(address indexed _account);
    event UnBlacklisted(address indexed _account);
    event BlacklisterChanged(address indexed newBlacklister);

    /**
     * @dev Throws if called by any account other than the blacklister.
     */
    modifier onlyBlacklister() {
        require(msg.sender == blacklister, "Blacklistable: caller is not the blacklister");
        _;
    }

    /**
     * @dev Checks if account is blacklisted.
     * @param _account The address to check.
     */
    function isBlacklisted(address _account) external view returns (bool) {
        return blacklisted[_account];
    }

    /**
     * @dev Adds account to blacklist.
     * @param _account The address to blacklist.
     */
    function blacklist(address _account) external onlyBlacklister {
        blacklisted[_account] = true;
        emit Blacklisted(_account);
    }

    /**
     * @dev Removes account from blacklist.
     * @param _account The address to remove from the blacklist.
     */
    function unBlacklist(address _account) external onlyBlacklister {
        blacklisted[_account] = false;
        emit UnBlacklisted(_account);
    }

    /**
     * @dev Updates address of the blasklister account.
     * Callable only by the proxy admin.
     * @param _newBlacklister address of new blacklister account.
     */
    function updateBlacklister(address _newBlacklister) external onlyAdmin {
        blacklister = _newBlacklister;
        emit BlacklisterChanged(blacklister);
    }
}
