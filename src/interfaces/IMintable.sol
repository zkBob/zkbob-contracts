//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IMintable {
    function mint(address,uint256) external returns(bool);
}