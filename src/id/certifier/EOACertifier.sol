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
 * @title EOACertifier
 */
contract EOACertifier is Ownable {
    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant ISSUE_EOA_CERTIFICATE_TYPEHASH =
        keccak256("IssueEOACertificate(address owner,uint96 expiration,bytes32 cert,bool primary)");

    BSID public immutable bsid;

    struct Operator {
        bool authorized;
        uint96 fee;
    }

    mapping(address => Operator) public operator;

    event OperatorUpdate(address indexed operator, bool enabled, uint96 fee);
    event Certificate(address indexed operator, uint48 indexed tokenId, bytes32 indexed cert, address to);

    constructor(address _bsid) {
        bsid = BSID(_bsid);
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("BSID EOA Certifier"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function updateOperator(address _operator, bool _enabled, uint96 _fee) external onlyOwner {
        operator[_operator] = Operator(_enabled, _fee);

        emit OperatorUpdate(_operator, _enabled, _fee);
    }

    function issue(address _to, uint40 _expiry, bytes32 _cert, bool _primary) external {
        require(operator[msg.sender].authorized, "EOACertifier: not authorized");

        _issue(msg.sender, _to, _expiry, _cert, _primary);
    }

    function issueOnBehalf(address _to, uint40 _expiry, bytes32 _cert, bool _primary, bytes calldata _sig)
        external
        payable
    {
        bytes32 digest = ECDSA.toTypedDataHash(
            DOMAIN_SEPARATOR, keccak256(abi.encode(ISSUE_EOA_CERTIFICATE_TYPEHASH, _to, _expiry, _cert, _primary))
        );

        address signer = ECDSA.recover(digest, _sig);

        Operator storage op = operator[signer];
        (bool authorized, uint96 fee) = (op.authorized, op.fee);

        require(authorized, "EOACertifier: not authorized");
        require(msg.value == fee, "EOACertifier: incorrect fee");

        _issue(signer, _to, _expiry, _cert, _primary);
    }

    function revoke(uint48 _tokenId) external {
        require(operator[msg.sender].authorized, "EOACertifier: not authorized");

        bsid.revoke(_tokenId);
    }

    function withdraw(address _to) external onlyOwner {
        payable(_to).transfer(address(this).balance);
    }

    function _issue(address _operator, address _to, uint40 _expiry, bytes32 _cert, bool _primary) internal {
        require(!Address.isContract(_to), "EOACertifier: not an EOA");

        uint48 tokenId = bsid.mint(_to, _expiry, _primary ? 1 : 0);

        emit Certificate(_operator, tokenId, _cert, _to);
    }
}
