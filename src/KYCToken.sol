// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract KYCToken is ERC721, Pausable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("KYCToken", "KYC") {
        _pause();
    }

    function acquire() external {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal whenNotPaused override {
        super._transfer(from, to, tokenId);
    }    
}
