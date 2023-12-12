// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "../../interfaces/IOperatorManager.sol";
import "../../utils/Ownable.sol";
import "../utils/CustomABIDecoder.sol";
import "../../../lib/@openzeppelin/contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title MPCOperatorManager
 * @dev Implements a specialized policy which utilizes offchain verifiers' signatures.
 */
contract MPCOperatorManager is IOperatorManager, Ownable, CustomABIDecoder {
    
    struct Operator {
        string URI;
        uint256 index;
        address feeReceiver;
    }

    address[] _operatorsList ;

    event Log(uint256);

    // mapping of all historical fee receiver addresses, we keep fee receivers addresses
    // in a mapping to allow fee withdrawals even after operator address was changed
    mapping(address => Operator ) public  _operatorsMap;

    event UpdateOperator(address indexed operator, address feeReceiver, string URI);

    modifier nonZeroAddress(address addr) {
        require(addr != address(0), "WhitelistBasedOperatorManager: zero address");
        _;
    }

    constructor(
        address[] memory _operators, 
        string[] memory URI,
        address[] memory _feeReceivers
    ) Ownable() {
        _setOperators(_operators, URI, _feeReceivers);
    }

    function setOperators(
        address[] calldata _operators, 
        string[] memory URI, 
        address[] calldata _feeReceivers
    ) external onlyOwner {
        _setOperators(_operators,URI, _feeReceivers);
    }

    function setOperator(
        address _operator, 
        string memory URI,
        address _feeReceiver
    ) external onlyOwner {
        _setOperator(_operator, _operatorsList.length, URI,_feeReceiver);
    }

    function operatorURI() external view returns (string memory) {
        return "";
    }

    function _setOperators(
        address[] memory _newOperators, 
        string[] memory _URI,
        address[] memory _feeReceivers
    ) internal {
        require(_newOperators.length >0, "MPCManager: operators absent");
        require(_newOperators.length == _feeReceivers.length, "MPCManager: feeReceivers length mismatch");
        require(_newOperators.length == _URI.length, "MPCManager: URI length mismatch");
        
        //if new list is shorter than current, delete all extra records before overwriting them
        if(_newOperators.length < _operatorsList.length) {
            for (uint256 index = _newOperators.length; index < _operatorsList.length; index++) {
                _operatorsList.pop();        
            }
        }
        //Overwrite all of the operators with new indices
        for (uint256 i = 0; i < _newOperators.length; i++) {
            emit Log(i+1);
            _setOperator(_newOperators[i],i+1, _URI[i], _feeReceivers[i]);
        }
    }

    function _setOperator(
        address _operator, 
        uint256 index,
        string memory URI,
        address _feeReceiver
    ) nonZeroAddress(_operator) internal {
        if (_feeReceiver != address(0) ) {
            
            _operatorsMap[_operator] = Operator(URI, index, _feeReceiver);
            _operatorsList.push(_operator);
        }
        emit UpdateOperator(_operator, _feeReceiver,URI);
    }

    function isOperator(address _addr) external view override returns (bool) {

        (uint8 count, bytes calldata signatures) = _mpc_signatures();
        uint256 bitmap = 0;
        uint256 _operatorsCount = _operatorsList.length;
        require(count == _operatorsCount, "MPCOperatorManager: bad quorum");
        // mapping(address => bool) storage signedMap = signedBy;

        for (uint256 index = 0; index < count; index++) { 
            uint256 offset = index*64;
            bytes32 r;
            bytes32 vs;
            assembly {
                r := calldataload(add(offset,signatures.offset))
                vs := calldataload(add(add(offset,64), add(signatures.offset,64)))
            }
            
            address signer = ECDSA.recover(
                ECDSA.toEthSignedMessageHash(
                    keccak256(_mpc_message())), r, vs
                );

            uint256 operatorIndex = _operatorsMap[signer].index;
            require(operatorIndex >0, "MPCOperatorManager: not authorized ");

            //indices must start at 1 so that we don't confuse it with empty value
            bitmap = bitmap & 1<< operatorIndex-1;   
        }
        return (bitmap == (1<<_operatorsCount - 1));
    }

    function isOperatorFeeReceiver(address _operator, address _addr) external view override returns (bool) {
        return _operatorsMap[_operator].feeReceiver == _addr;
    }
}
