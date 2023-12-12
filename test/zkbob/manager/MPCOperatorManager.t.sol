pragma solidity ^0.8.15;
import "forge-std/Test.sol";
import "../../../src/zkbob/manager/MPCOperatorManager.sol";
import "../ZkBobPool.t.sol";
import "../../shared/Env.t.sol";

import "../../shared/ForkTests.t.sol";

contract MPCOperatorManagerTest is
    AbstractZkBobPoolTest,
    AbstractPolygonForkTest
{
    address[] signers;

    constructor() {
        D = 1;
        token = address(0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B);
        weth = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
        tempToken = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        poolType = PoolType.BOB;
        autoApproveQueue = false;
        permitType = PermitType.BOBPermit;
        denominator = 1_000_000_000;
        precision = 1_000_000_000;
    }

    function testIsOperator() public {
        address operator = makeAddr("operator");

        

        MPCOperatorManager _manager = new MPCOperatorManager(
            operator,
            operator,
            "_"
        );
        _manager.transferOwnership(operator);

        (address signer1Addr, uint256 signer1Key) = makeAddrAndKey("signer1");
        (address signer2Addr, uint256 signer2Key) = makeAddrAndKey("signer1");
        signers.push(signer1Addr);
        signers.push(signer2Addr);
        vm.prank(operator);
        _manager.setSigners(signers);

        bytes memory data = _encodeDeposit(1 ether, 0.1 ether);
        data = abi.encodePacked(data, uint8(2));
        data = appendSignature(data, signer1Key);
        data = appendSignature(data, signer2Key);

        assert(_manager.isOperator(operator));

    }


    function  appendSignature(bytes memory data, uint256 key ) internal returns ( bytes memory updated ) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            key,
            keccak256(data)
        );
        updated = abi.encodePacked(data, r, uint256(s) + (v == 28 ? (1 << 255) : 0));
    }
}
