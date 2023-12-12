pragma solidity ^0.8.15;
import "forge-std/Test.sol";
import "../../../src/zkbob/manager/MPCOperatorManager.sol";

contract MPCOperatorManagerTest is Test {

    // MPCOperatorManager _manager;

    
    address bar = makeAddr("bar");
    address signer1Addr;
    uint256 signer1Key;

    address[]  signers ;

    function setUp() public {
        
        (signer1Addr,  signer1Key) = makeAddrAndKey("signer1");
        // (address signer2Addr, uint256 signer2Key) = makeAddrAndKey("signer2");
        // (address signer3Addr, uint256 signer3Key) = makeAddrAndKey("signer3");

        signers.push(signer1Addr);
        // signers.push(signer2Addr);
        // signers.push(signer3Addr);
    }

    function testInit() public {

        MPCOperatorManager _manager = new MPCOperatorManager(signer1Addr, signer1Addr, "");

        // _manager.setSigners(_signers);
        // 
    }

    function testIsOperator() public {
        // vm.prank(foo);

    }
}
