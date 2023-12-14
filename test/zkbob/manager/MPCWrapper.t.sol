pragma solidity ^0.8.15;
import "forge-std/Test.sol";

import "../ZkBobPool.t.sol";
import "../../shared/Env.t.sol";

import "../../shared/ForkTests.t.sol";

contract MPCOperatorManagerTest is
    AbstractZkBobPoolTest,
    AbstractPolygonForkTest
{
    constructor() {
        isMPC = true;
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

    function testDepositMPC() public {
        vm.prank(user1);
        IERC20(token).approve(address(pool),1 ether);
        bytes memory data = withMPC(_encodeDeposit(0.1 ether, 0.01 ether)); //752
        _transactMPC(data);
    }
    function testPermitDepositMPC() public {
        bytes memory data = withMPC(_encodePermitDeposit(0.1 ether, 0.01 ether)); //752
        _transactMPC(data);
    }

    function _transactMPC(bytes memory data) internal {
        address operator = makeAddr("operatorEOA");
        address wrapper = operatorManager.operator();
        vm.prank(operator);
        (bool status, ) = address(wrapper).call(data);
        require(status, "transact() reverted");
    }

    function withMPC(bytes memory data) internal returns (bytes memory){
        (address signer1Addr, uint256 signer1Key) = makeAddrAndKey("signer1");
        (address signer2Addr, uint256 signer2Key) = makeAddrAndKey("signer2");
        return abi.encodePacked(
            data,
            uint8(2),//753
            sign(data, signer1Key),//817
            sign(data, signer2Key)//881
        );
    }
    function sign(
        bytes memory data,
        uint256 key
    ) internal returns (bytes memory signatureData) {
        bytes32 digest = ECDSA.toEthSignedMessageHash(keccak256(data));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        signatureData = abi.encodePacked(
            r,
            uint256(s) + (v == 28 ? (1 << 255) : 0)
        );
    }
}
