// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";

contract SingletonFactory {
    function deploy(bytes memory _initCode, bytes32 _salt) public returns (address payable createdContract) {
        assembly {
            createdContract := create2(0, add(_initCode, 0x20), mload(_initCode), _salt)
        }
    }
}

abstract contract EIP2470Test is Test {
    SingletonFactory public factory = SingletonFactory(0xce0042B868300000d44A59004Da54A005ffdcf9f);

    function setUpFactory() public {
        vm.etch(address(factory), type(SingletonFactory).runtimeCode);
    }
}
