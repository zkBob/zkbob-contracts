//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./MintableToken.sol";

contract PermittableToken is MintableToken {
    string public constant version = "1";

    // EIP712 niceties
    bytes32 public DOMAIN_SEPARATOR;
    // bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    // bytes32 public constant SALTED_PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline,bytes32 salt)");
    bytes32 public constant SALTED_PERMIT_TYPEHASH = 0x4bcf1917b4c6060d0cfc29abba53999d42824efa953155f8c376edb9e22cad8c;

    mapping(address => uint256) public nonces;

    constructor(string memory name_, string memory symbol_, address _minter)
        MintableToken(name_, symbol_, _minter)
    {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name_)),
                keccak256(bytes(version)),
                1,
                address(this)
            )
        );
    }

    /** @dev Allows to spend holder's specified amount by the specified spender according to EIP2612.
     * The function can be called by anyone, but requires having allowance parameters
     * signed by the holder according to EIP712.
     * @param _holder The holder's address.
     * @param _spender The spender's address.
     * @param _value Allowance value to set as a result of the call.
     * @param _deadline The deadline timestamp to call the permit function. Must be a timestamp in the future.
     * Note that timestamps are not precise, malicious miner/validator can manipulate them to some extend.
     * Assume that there can be a 900 seconds time delta between the desired timestamp and the actual expiration.
     * @param _v A final byte of signature (ECDSA component).
     * @param _r The first 32 bytes of signature (ECDSA component).
     * @param _s The second 32 bytes of signature (ECDSA component).
     */
    function permit(
        address _holder,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        require(block.timestamp <= _deadline);

        uint256 nonce = nonces[_holder]++;
        bytes32 digest = _digest(abi.encode(PERMIT_TYPEHASH, _holder, _spender, _value, nonce, _deadline));
        require(_holder == _recover(digest, _v, _r, _s));

        _approve(_holder, _spender, _value);
    }

    function saltedPermit(
        address _holder,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        bytes32 _salt,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        external
    {
        require(block.timestamp <= _deadline);

        uint256 nonce = nonces[_holder]++;
        bytes32 digest = _digest(abi.encode(SALTED_PERMIT_TYPEHASH, _holder, _spender, _value, nonce, _deadline, _salt));
        require(_holder == _recover(digest, _v, _r, _s));

        _approve(_holder, _spender, _value);
    }

    function receiveWithSaltedPermit(
        address _holder,
        uint256 _value,
        uint256 _deadline,
        bytes32 _salt,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        public
        virtual
    {
        require(block.timestamp <= _deadline);

        uint256 nonce = nonces[_holder]++;
        bytes32 digest = _digest(abi.encode(SALTED_PERMIT_TYPEHASH, _holder, _msgSender(), _value, nonce, _deadline, _salt));
        require(_holder == _recover(digest, _v, _r, _s));

        emit Approval(_holder, _msgSender(), _value);
        emit Approval(_holder, _msgSender(), 0);

        _transfer(_holder, _msgSender(), _value);
    }

    /**
     * @dev Calculates the message digest for encoded EIP712 typed struct.
     * @param _typedStruct encoded payload.
     */
    function _digest(bytes memory _typedStruct) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, keccak256(_typedStruct)));
    }

    /**
     * @dev Derives the signer address for the given message digest and ECDSA signature params.
     * @param _msg_digest signed message digest.
     * @param _v a final byte of signature (ECDSA component).
     * @param _r the first 32 bytes of the signature (ECDSA component).
     * @param _s the second 32 bytes of the signature (ECDSA component).
     */
    function _recover(bytes32 _msg_digest, uint8 _v, bytes32 _r, bytes32 _s) internal pure returns (address) {
        require(_v == 27 || _v == 28, "ECDSA: invalid signature 'v' value");
        require(
            uint256(_s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
            "ECDSA: invalid signature 's' value"
        );

        address signer = ecrecover(_msg_digest, _v, _r, _s);
        require(signer != address(0), "ECDSA: invalid signature");

        return signer;
    }
}
