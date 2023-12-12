// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "./MutableOperatorManager.sol";
import "../../utils/Ownable.sol";
import "../utils/CustomABIDecoder.sol";
import "../../../lib/@openzeppelin/contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title MPCOperatorManager
 * @dev Implements a specialized policy which utilizes offchain verifiers' signatures.
 */
contract MPCOperatorManager is
    MutableOperatorManager,
    CustomABIDecoder
{
    address[] private signers;

    // constructor(
    //     address _operator,
    //     address _feeReceiver,
    //     string memory _operatorURI
    // ) Ownable() {
    //     new MutableOperatorManager(_operator, _feeReceiver, _operatorURI);
    // }

    constructor(address _operator, address _feeReceiver, string memory _operatorURI) Ownable() {
        new MutableOperatorManager(_operator, _feeReceiver, _operatorURI);
    }

    function setSigners(address[] calldata _signers ) external onlyOwner {
        signers = _signers;
    }

    function isOperator(address _addr) external view override returns (bool) {
         if (!super.isOperator(_addr)) {
            return false;
        }
        (uint8 count, bytes calldata signatures) = _mpc_signatures();
        uint256 _signersCount = signers.length;
        require(count == _signersCount, "MPCOperatorManager: bad quorum");
        uint256 offset = 0;
        for (uint256 index = 0; index < _signersCount; index++) {
            bytes32 r;
            bytes32 vs;
            assembly {
                offset := add(offset, signatures.offset)
                r := calldataload(offset)
                offset := add(offset, 32)
                vs := calldataload(offset)
                offset := add(offset, 32)
            }

            address signer = ECDSA.recover(
                ECDSA.toEthSignedMessageHash(keccak256(_mpc_message())),
                r,
                vs
            );
            if (signer == signers[index]) {
                return false;
            }
        }
        return true;
    }
}
