// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../utils/Ownable.sol";
import "../proxy/EIP1967Admin.sol";

/**
 * @title BSID
 */
contract BSID is ERC165, EIP1967Admin, Ownable {
    // Token name
    string public constant name = "BlockScout ID";

    // Token symbol
    string public constant symbol = "BSID";

    // Token URI
    string public tokenURI;

    struct SBT {
        address owner;
        uint40 expiry;
        uint48 meta;
        uint8 typ;
    }

    struct ActiveSBT {
        uint48 id;
        uint40 expiry;
    }

    uint48 internal nextTokenId;

    mapping(uint48 => SBT) public sbt;

    // owner => nft subtype => active nft
    mapping(address => mapping(uint8 => ActiveSBT)) public active;

    // certifier => nft subtype
    mapping(address => uint8) public certifier;

    event CertifierUpdate(address indexed certifier, uint8 typ);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Mint(address indexed owner, uint8 indexed typ, uint48 indexed tokenId, uint40 expiry);
    event Update(address indexed owner, uint8 indexed typ, uint48 indexed tokenId, uint40 expiry);
    event Revoke(address indexed owner, uint8 indexed typ, uint48 indexed tokenId, uint40 expiry);

    function initialize() external {
        require(nextTokenId == 0, "Already initialized");
        nextTokenId = 1;
    }

    function setTokenURI(string memory _tokenURI) external onlyOwner {
        tokenURI = _tokenURI;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = sbt[uint48(tokenId)].owner;
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    function balanceOf(address user) external view returns (uint256) {
        return 0;
    }

    function updateCertifier(address _certifier, uint8 _typ) external onlyOwner {
        certifier[_certifier] = _typ;

        emit CertifierUpdate(_certifier, _typ);
    }

    /**
     * @dev Mints a new BSID NFT.
     * Caller should be a valid certifier with non-zero subtype associated to it.
     * Target address can have only one non-expired NFT of specific type at any given point in time.
     * For replacing existing NFT, user must first revoke active NFT, then can mint a new one.
     * @param _to target address where NFT should be minted.
     * @param _expiry expiration date, should be at least 1 day in the future, at most 10 years in the future.
     * @param _meta any extra metadata to store within the NFT for further usage. Not used in BSID contract, but used in external verifiers.
     */
    function mint(address _to, uint40 _expiry, uint48 _meta) external returns (uint48) {
        require(_to != address(0), "BSID: mint to the zero address");
        require(_expiry > block.timestamp + 1 days, "BSID: expiry too low");
        require(_expiry < block.timestamp + 3650 days, "BSID: expiry too high");

        uint8 typ = certifier[msg.sender];
        require(typ > 0, "BSID: not a certifier");

        require(active[_to][typ].expiry < block.timestamp, "BSID: not yet expired");

        uint48 tokenId = nextTokenId++;
        sbt[tokenId] = SBT(_to, _expiry, _meta, typ);
        active[_to][typ] = ActiveSBT(tokenId, _expiry);

        emit Transfer(address(0), _to, tokenId);
        emit Mint(_to, typ, tokenId, _expiry);

        return tokenId;
    }

    /**
     * @dev Updates an existing NFT.
     * Caller should be either a certifier for the specific NFT type or the smart contract owner.
     * Token ID should belong to an existing non-expired NFT.
     * @param _tokenId token id to update information for.
     * @param _expiry new expiration date for the updated NFT.
     * @param _meta new extra metadata to store within the NFT.
     */
    function update(uint48 _tokenId, uint40 _expiry, uint48 _meta) external {
        require(_expiry > block.timestamp + 1 days, "BSID: expiry too low");
        require(_expiry < block.timestamp + 3650 days, "BSID: expiry too high");

        SBT storage token = sbt[_tokenId];
        (address owner, uint40 expiry, uint8 typ) = (token.owner, token.expiry, token.typ);
        require(expiry > block.timestamp, "BSID: can't update expired token");
        require(typ > 0, "BSID: not a valid token id");
        require(certifier[msg.sender] == typ || _isOwner(), "BSID: not authorized");

        (token.expiry, token.meta) = (_expiry, _meta);
        active[owner][typ] = ActiveSBT(_tokenId, _expiry);

        emit Update(owner, typ, _tokenId, _expiry);
    }

    /**
     * @dev Revokes active NFT.
     * Caller should be either a certifier for the specific NFT type or the smart contract owner or the NFT owner.
     * Token ID should belong to an existing non-expired NFT.
     * After revoke, NFT cannot be updated anymore, however the new one might be issued once again.
     * @param _tokenId token id to revoke.
     */
    function revoke(uint48 _tokenId) external {
        SBT storage token = sbt[_tokenId];
        (address owner, uint8 typ) = (token.owner, token.typ);
        require(typ > 0, "BSID: not a valid token id");
        require(msg.sender == owner || certifier[msg.sender] == typ || _isOwner(), "BSID: not authorized");

        uint40 expiry = uint40(block.timestamp);
        token.expiry = expiry;
        active[owner][typ].expiry = expiry;

        emit Revoke(owner, typ, _tokenId, expiry);
    }

    function isActiveToken(uint48 _tokenId) external view returns (bool) {
        return sbt[_tokenId].expiry > block.timestamp;
    }

    function hasActiveTokenByType(address _owner, uint8 _typ) external view returns (bool) {
        return active[_owner][_typ].expiry > block.timestamp;
    }

    function getActiveTokenByType(address _owner, uint8 _typ) external view returns (uint48, uint40) {
        ActiveSBT memory activeSBT = active[_owner][_typ];
        if (activeSBT.expiry > block.timestamp) {
            return (activeSBT.id, activeSBT.expiry);
        }
        return (0, 0);
    }

    function getActiveTokenMetaByType(address _owner, uint8 _typ) external view returns (uint48, uint48) {
        ActiveSBT memory activeSBT = active[_owner][_typ];
        if (activeSBT.expiry > block.timestamp) {
            return (activeSBT.id, sbt[activeSBT.id].meta);
        }
        return (0, 0);
    }

    /**
     * @dev Tells if caller is the contract owner.
     * Gives ownership rights to the proxy admin as well.
     * @return true, if caller is the contract owner or proxy admin.
     */
    function _isOwner() internal view override returns (bool) {
        return super._isOwner() || _admin() == _msgSender();
    }
}
