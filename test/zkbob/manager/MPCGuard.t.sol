pragma solidity ^0.8.15;
import "forge-std/Test.sol";

import "../ZkBobPool.t.sol";
import "../../shared/Env.t.sol";

import "../../shared/ForkTests.t.sol";

import "../../../src/zkbob/manager/MPCGuard.sol";

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
        IERC20(token).approve(address(pool), 1 ether);
        bytes memory data = withMPC(_encodeDeposit(0.1 ether, 0.01 ether)); //752
        _transactMPC(data);
    }

    function testPermitDepositMPC() public {
        bytes memory data = withMPC(
            _encodePermitDeposit(0.1 ether, 0.01 ether)
        ); //752
        _transactMPC(data);
    }

    function _transactMPC(bytes memory data) internal {
        address operator = makeAddr("operatorEOA");
        address wrapper = operatorManager.operator();
        vm.prank(operator);
        (bool status, ) = address(wrapper).call(data);
        require(status, "transact() reverted");
    }

    function withMPC(bytes memory data) internal returns (bytes memory) {
        (, uint256 guard1Key) = makeAddrAndKey("guard1");
        (, uint256 guard2Key) = makeAddrAndKey("guard2");
        return
            abi.encodePacked(
                data,
                uint8(2), //753
                sign(data, guard1Key), //817
                sign(data, guard2Key) //881
            );
    }

    function testAppendDirectDepositsMPC() public {
        _setUpDD();

        address wrapper = operatorManager.operator();

        vm.startPrank(user1);
        _directDeposit(10 ether / D, user2, zkAddress);
        _directDeposit(5 ether / D, user2, zkAddress);
        vm.stopPrank();

        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        address verifier = address(pool.batch_deposit_verifier());
        uint256 outCommitment = _randFR();
        bytes memory data = abi.encodePacked(
            outCommitment,
            bytes10(0xc2767ac851b6b1e19eda), // first deposit receiver zk address (42 bytes)
            bytes32(
                0x2f6f6ef223959602c05afd2b73ea8952fe0a10ad19ed665b3ee5a0b0b9e4e3ef
            ),
            uint64(9.9 ether / D / denominator), // first deposit amount
            bytes10(0xc2767ac851b6b1e19eda), // second deposit receiver zk address (42 bytes)
            bytes32(
                0x2f6f6ef223959602c05afd2b73ea8952fe0a10ad19ed665b3ee5a0b0b9e4e3ef
            ),
            uint64(4.9 ether / D / denominator), // second deposit amount
            new bytes(14 * 50)
        );
        vm.expectCall(
            verifier,
            abi.encodeWithSelector(
                IBatchDepositVerifier.verifyProof.selector,
                [uint256(keccak256(data)) %
                    21888242871839275222246405745257275088548364400416034343698204186575808495617]
            )
        );
        vm.expectEmit(true, false, false, true);
        emit CompleteDirectDepositBatch(indices);
        bytes memory message = abi.encodePacked(
            bytes4(0x02000001), // uint16(2) in little endian ++ MESSAGE_PREFIX_DIRECT_DEPOSIT_V1
            uint64(0), // first deposit nonce
            bytes10(0xc2767ac851b6b1e19eda), // first deposit receiver zk address (42 bytes)
            bytes32(
                0x2f6f6ef223959602c05afd2b73ea8952fe0a10ad19ed665b3ee5a0b0b9e4e3ef
            ),
            uint64(9.9 ether / D / denominator), // first deposit amount
            uint64(1), // second deposit nonce
            bytes10(0xc2767ac851b6b1e19eda), // second deposit receiver zk address (42 bytes)
            bytes32(
                0x2f6f6ef223959602c05afd2b73ea8952fe0a10ad19ed665b3ee5a0b0b9e4e3ef
            ),
            uint64(4.9 ether / D / denominator) // second deposit amount
        );
        // vm.expectEmit(true, false, false, true);
        emit Message(128, bytes32(0), message);
        
        uint256 root_afer = _randFR();
        uint256[8] memory batch_deposit_proof = _randProof();
        uint256[8] memory tree_proof = _randProof();
        bytes memory mpcMessage = abi.encodePacked(
            ZkBobPool.appendDirectDeposits.selector,
            root_afer,
            indices,
            outCommitment,
            batch_deposit_proof,
            tree_proof
        );

        (, uint256 guard1Key) = makeAddrAndKey("guard1");
        (, uint256 guard2Key) = makeAddrAndKey("guard2");

        vm.prank(makeAddr("operatorEOA"));
        MPCGuard(wrapper).appendDirectDepositsMPC(
            root_afer,
            indices,
            outCommitment,
            batch_deposit_proof,
            tree_proof,
            abi.encodePacked(sign(mpcMessage, guard1Key), sign(mpcMessage, guard2Key))
        );
        
    }

    function sign(
        bytes memory data,
        uint256 key
    ) internal pure returns (bytes memory signatureData) {

        bytes32 digest = ECDSA.toEthSignedMessageHash(keccak256(data));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        signatureData = abi.encodePacked(
            r,
            uint256(s) + (v == 28 ? (1 << 255) : 0)
        );
    }
}
