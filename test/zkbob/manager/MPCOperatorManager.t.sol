pragma solidity ^0.8.15;
import "forge-std/Test.sol";
import "../../../src/zkbob/manager/MPCOperatorManager.sol";

contract MPCOperatorManagerTest is Test {
    address[] _addresses;
    address[] _feeReceivers;
    string[] _URI;
    // MPCOperatorManager _manager;

    (address fooAddr, uint256 key) = makeAddrAndKey("1337"); = makeAddr("foo");
    address bar = makeAddr("bar");

    function setUp() public {
        _addresses.push(foo);
        _URI.push("foo");
        _feeReceivers.push(foo);
        _addresses.push(bar);
        _URI.push("bar");
        _feeReceivers.push(bar);
    }

    function testInit() public {

        MPCOperatorManager _manager = new MPCOperatorManager(_addresses, _URI, _feeReceivers);

        (string memory URI,uint256 index,) =  _manager._operatorsMap(foo);
        assertEq("foo", URI);
        assertEq(index, 1);  
        
        (URI,index,) =  _manager._operatorsMap(bar);
        assertEq("bar", URI);
        assertEq(index, 2);   
    }

    function testIsOperator() public {
        vm.prank(foo);

    }
}
