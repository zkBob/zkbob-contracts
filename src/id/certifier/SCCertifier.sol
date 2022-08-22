// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../utils/Ownable.sol";
import "../../proxy/EIP1967Admin.sol";
import "../BSID.sol";

/**
 * @title SCCertifier
 */
contract SCCertifier is Ownable {
    BSID public immutable bsid;

    event Certificate(address indexed operator, uint48 indexed tokenId, address to);

    constructor(address _bsid) {
        bsid = BSID(_bsid);
    }

    function issue(address _to, uint40 _expiry, uint48 _meta) external onlyOwner {
        require(Address.isContract(_to), "SCCertifier: not a contract");

        uint48 tokenId = bsid.mint(_to, _expiry, _meta);

        emit Certificate(_to, tokenId, _to);
    }

    function revoke(uint48 _tokenId) external onlyOwner {
        bsid.revoke(_tokenId);
    }
}
