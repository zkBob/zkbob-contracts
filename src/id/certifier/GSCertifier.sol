// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../interfaces/IGnosisSafe.sol";
import "../../utils/Ownable.sol";
import "../../proxy/EIP1967Admin.sol";
import "../BSID.sol";
import "./BSIDType.sol";

/**
 * @title GSCertifier
 */
contract GSCertifier is Ownable {
    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant ISSUE_GS_CERTIFICATE_TYPEHASH = keccak256("IssueGSCertificate(address safe)");
    bytes32 public constant REVOKE_GS_CERTIFICATE_TYPEHASH = keccak256("RevokeGSCertificate(address safe)");

    BSID public immutable bsid;

    uint256 public fee;

    event Certificate(uint48 indexed tokenId, uint48 indexed ownerTokenId, address owner, address to);

    constructor(address _bsid) {
        bsid = BSID(_bsid);
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("BSID GS Certifier"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    function issue(address _to, uint256 _tokenId) external payable {
        require(msg.value == fee, "GSCertifier: incorrect fee");

        _issue(msg.sender, _to);
    }

    function issueOnBehalf(address _to, bytes calldata _sig) external payable {
        require(msg.value == fee, "GSCertifier: incorrect fee");

        bytes32 digest =
            ECDSA.toTypedDataHash(DOMAIN_SEPARATOR, keccak256(abi.encode(ISSUE_GS_CERTIFICATE_TYPEHASH, _to)));
        address signer = ECDSA.recover(digest, _sig);

        _issue(signer, _to);
    }

    function revokeFrom(address _to) external {
        _revoke(msg.sender, _to);
    }

    function revokeFromOnBehalf(address _to, bytes calldata _sig) external {
        bytes32 digest =
            ECDSA.toTypedDataHash(DOMAIN_SEPARATOR, keccak256(abi.encode(REVOKE_GS_CERTIFICATE_TYPEHASH, _to)));
        address signer = ECDSA.recover(digest, _sig);

        _revoke(signer, _to);
    }

    function withdraw(address _to) external onlyOwner {
        payable(_to).transfer(address(this).balance);
    }

    function _issue(address _issuer, address _to) internal {
        require(IGnosisSafe(_to).isOwner(msg.sender), "GSCertifier: not a safe owner");

        (uint48 activeId, uint40 expiry) = bsid.getActiveTokenByType(_issuer, uint8(BSIDType.EOA));

        require(activeId > 0, "GSCertifier: no active token");

        uint48 tokenId = bsid.mint(_to, expiry, activeId);

        emit Certificate(tokenId, activeId, _issuer, _to);
    }

    function _revoke(address _owner, address _to) internal {
        (uint48 tokenId, uint48 meta) = bsid.getActiveTokenMetaByType(_to, uint8(BSIDType.GS));
        require(tokenId > 0, "GSCertifier: no active token");
        require(_owner == bsid.ownerOf(meta), "GSCertifier: different owner");
        bsid.revoke(tokenId);
    }
}
