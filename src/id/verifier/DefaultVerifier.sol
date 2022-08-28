// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/Address.sol";
import "../BSID.sol";
import "../certifier/BSIDType.sol";

/**
 * @title DefaultVerifier
 */
contract DefaultVerifier {
    BSID public immutable bsid;

    constructor(address _bsid) {
        bsid = BSID(_bsid);
    }

    function _isAddressVerified(address _owner) internal view returns (bool) {
        if (Address.isContract(_owner)) {
            if (bsid.hasActiveTokenByType(_owner, uint8(BSIDType.SC))) {
                return true;
            }
            (uint48 tokenId, uint48 meta) = bsid.getActiveTokenMetaByType(_owner, uint8(BSIDType.GS));
            return tokenId > 0 && bsid.isActiveToken(meta);
        }
        return bsid.hasActiveTokenByType(_owner, uint8(BSIDType.EOA));
    }
}
