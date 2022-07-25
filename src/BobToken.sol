// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IERC677.sol";
import "./interfaces/IERC677Receiver.sol";
import "./proxy/EIP1967Admin.sol";

/**
 * @title BobToken
 */
contract BobToken is IERC677, ERC20, EIP1967Admin {
    // EIP712 niceties
    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    address public minter;
    mapping(address => uint256) public nonces;
    mapping(address => mapping(address => uint256)) public expirations;

    constructor(address self) ERC20("", "") {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name())),
                keccak256("1"),
                block.chainid,
                self
            )
        );
    }

    function name() public view override returns (string memory) {
        return "BOB";
    }

    function symbol() public view override returns (string memory) {
        return "BOB";
    }

    function setMinter(address _minter) external onlyAdmin {
        minter = _minter;
    }

    function mint(address _to, uint256 _amount) external {
        require(_msgSender() == minter, "BOB: not a minter");

        _mint(_to, _amount);
    }

    function transferAndCall(address _to, uint256 _amount, bytes calldata _data) external override {
        address sender = msg.sender;
        _transfer(sender, _to, _amount);
        require(IERC677Receiver(_to).onTokenTransfer(sender, _amount, _data), "BOB: ERC677 callback failed");
    }

    /**
     * @dev Allows to spend holder's unlimited amount by the specified spender according to EIP2612.
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
    )
        external
    {
        require(block.timestamp <= _deadline, "BOB: expired permit");

        uint256 nonce = nonces[_holder]++;
        bytes32 digest = ECDSA.toTypedDataHash(
            DOMAIN_SEPARATOR, keccak256(abi.encode(PERMIT_TYPEHASH, _holder, _spender, _value, nonce, _deadline))
        );

        require(_holder == ECDSA.recover(digest, _v, _r, _s), "BOB: invalid signature");

        _approve(_holder, _spender, _value);
    }
}
