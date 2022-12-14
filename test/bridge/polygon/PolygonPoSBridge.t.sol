// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../../shared/Env.t.sol";
import "../../../src/bridge/polygon/PolygonBobToken.sol";
import "../../../src/proxy/EIP1967Proxy.sol";

interface IRootChainManager {
    function registerPredicate(bytes32 tokenType, address predicate) external;
    function mapToken(address rootToken, address childToken, bytes32 tokenType) external;
    function depositFor(address user, address rootToken, bytes memory depositData) external;
}

interface IChildChainManager {
    function onStateReceive(uint256, bytes calldata data) external;
}

interface IBobPredicate {
    function exitTokens(address, address rootToken, bytes memory log) external;
}

contract PolygonPoSBridge is Test {
    event LockedERC20(
        address indexed depositor, address indexed depositReceiver, address indexed rootToken, uint256 amount
    );
    event Withdrawn(address indexed account, uint256 value);

    BobToken bobMainnet;
    PolygonBobToken bobPolygon;

    uint256 mainnetFork;
    uint256 polygonFork;

    address bobPredicate;
    address rootChainManager = 0xA0c68C638235ee32657e8f720a23ceC1bFc77C77;
    address rootChainManagerOwner = 0xFa7D2a996aC6350f4b56C043112Da0366a59b74c;
    address childChainManager = 0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa;
    address stateSyncer = 0x0000000000000000000000000000000000001001;

    function setUp() public {
        mainnetFork = vm.createFork(forkRpcUrlMainnet);
        polygonFork = vm.createFork(forkRpcUrlPolygon);

        vm.selectFork(mainnetFork);

        EIP1967Proxy bobProxy = new EIP1967Proxy(address(this), mockImpl, "");
        BobToken bobImpl = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(bobImpl));
        bobMainnet = BobToken(address(bobProxy));

        bobMainnet.updateMinter(address(this), true, false);

        vm.selectFork(polygonFork);

        bobProxy = new EIP1967Proxy(address(this), mockImpl, "");
        PolygonBobToken bobImpl2 = new PolygonBobToken(address(bobProxy));
        bobProxy.upgradeTo(address(bobImpl2));
        bobPolygon = PolygonBobToken(address(bobProxy));

        bobPolygon.updateMinter(address(this), true, false);
        bobPolygon.updateMinter(childChainManager, true, true);

        vm.selectFork(mainnetFork);

        vm.etch(rootChainManagerOwner, "");
        vm.startPrank(rootChainManagerOwner);
        bytes memory predicateCode = bytes.concat(
            vm.getCode("out/PolygonERC20MintBurnPredicate.sol/PolygonERC20MintBurnPredicate.json"),
            abi.encode(rootChainManager)
        );
        assembly {
            sstore(bobPredicate.slot, create(0, add(predicateCode, 32), mload(predicateCode)))
        }
        IRootChainManager(rootChainManager).registerPredicate(keccak256("BOB"), bobPredicate);
        vm.recordLogs();
        IRootChainManager(rootChainManager).mapToken(address(bobMainnet), address(bobPolygon), keccak256("BOB"));
        vm.stopPrank();
        _syncState();

        bobMainnet.updateMinter(bobPredicate, true, true);

        vm.label(address(bobMainnet), "BOB");
        vm.label(address(bobPolygon), "BOB");
    }

    function _syncState() internal {
        uint256 curFork = vm.activeFork();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        vm.selectFork(polygonFork);
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == bytes32(0x103fed9db65eac19c4d870f49ab7520fe03b99f1838e5996caf47e9e43308392)) {
                vm.prank(stateSyncer);
                IChildChainManager(childChainManager).onStateReceive(0, abi.decode(logs[i].data, (bytes)));
            }
        }
        vm.selectFork(curFork);
    }

    function testBridgeToPolygon() public {
        vm.selectFork(mainnetFork);

        bobMainnet.mint(user1, 100 ether);

        vm.startPrank(user1);
        bobMainnet.approve(bobPredicate, 10 ether);
        vm.expectEmit(true, true, true, true, bobPredicate);
        emit LockedERC20(user1, user2, address(bobMainnet), 10 ether);
        vm.recordLogs();
        IRootChainManager(rootChainManager).depositFor(user2, address(bobMainnet), abi.encode(10 ether));
        vm.stopPrank();

        _syncState();

        assertEq(bobMainnet.totalSupply(), 90 ether);
        assertEq(bobMainnet.balanceOf(user1), 90 ether);

        vm.selectFork(polygonFork);

        assertEq(bobPolygon.totalSupply(), 10 ether);
        assertEq(bobPolygon.balanceOf(user2), 10 ether);
    }

    function testBridgeFromPolygon() public {
        vm.selectFork(polygonFork);

        bobPolygon.mint(user1, 100 ether);

        vm.prank(user1);
        vm.expectEmit(true, false, false, true, address(bobPolygon));
        emit Withdrawn(user1, 10 ether);
        bobPolygon.withdraw(10 ether);

        vm.selectFork(mainnetFork);

        // cast --to-rlp '["<token>", ["<topic0>", "<topic1>"], "<data>"]'
        bytes memory logRLP = bytes.concat(
            hex"f87a94",
            abi.encodePacked(address(bobPolygon)),
            hex"f842a0",
            keccak256("Withdrawn(address,uint256)"),
            hex"a0",
            abi.encode(user1),
            hex"a0",
            abi.encode(10 ether)
        );

        vm.etch(rootChainManager, "");
        vm.prank(rootChainManager);
        IBobPredicate(bobPredicate).exitTokens(user1, address(bobMainnet), logRLP);

        assertEq(bobMainnet.totalSupply(), 10 ether);
        assertEq(bobMainnet.balanceOf(user1), 10 ether);

        vm.selectFork(polygonFork);

        assertEq(bobPolygon.totalSupply(), 90 ether);
        assertEq(bobPolygon.balanceOf(user1), 90 ether);
    }
}
