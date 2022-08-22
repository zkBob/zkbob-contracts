//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MintableToken is Ownable, ERC20 {

    address immutable public minter;

    constructor(string memory name_, string memory symbol_, address _minter) ERC20(name_, symbol_)  {
        minter = _minter;
    }

    function mint(address _to, uint256 _value) external returns(bool) {
        require(minter==address(0) || msg.sender==minter);
        _mint(_to, _value);
        return true;
    }
}
