// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../../shared/Env.t.sol";
import "../../../src/BobToken.sol";
import "../../../src/proxy/EIP1967Proxy.sol";
import "../../../src/bridge/optimism/L1BobBridge.sol";
import "../../../src/bridge/optimism/L2BobBridge.sol";

interface IMessageRelay {
    function relayMessage(address _target, address _sender, bytes memory _message, uint256 _messageNonce) external;
}

contract OptimismBridge is Test {
    event ERC20DepositInitiated(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );
    event ERC20WithdrawalFinalized(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );
    event WithdrawalInitiated(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );
    event DepositFinalized(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );

    BobToken bobMainnet;
    BobToken bobOptimism;

    uint256 mainnetFork;
    uint256 optimismFork;

    L1BobBridge l1Bridge;
    L2BobBridge l2Bridge;

    address l1Messenger = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
    address l2Messenger = 0x4200000000000000000000000000000000000007;

    function setUp() public {
        mainnetFork = vm.createFork(forkRpcUrlMainnet);
        optimismFork = vm.createFork(forkRpcUrlOptimism);

        vm.selectFork(mainnetFork);

        EIP1967Proxy l1BridgeProxy = new EIP1967Proxy(address(this), mockImpl, "");

        EIP1967Proxy bobProxy = new EIP1967Proxy(address(this), mockImpl, "");
        BobToken bobImpl = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(bobImpl));
        bobMainnet = BobToken(address(bobProxy));

        bobMainnet.updateMinter(address(this), true, false);
        bobMainnet.updateMinter(address(l1BridgeProxy), true, true);

        vm.selectFork(optimismFork);

        EIP1967Proxy l2BridgeProxy = new EIP1967Proxy(address(this), mockImpl, "");

        bobProxy = new EIP1967Proxy(address(this), mockImpl, "");
        BobToken bobImpl2 = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(bobImpl2));
        bobOptimism = BobToken(address(bobProxy));

        bobOptimism.updateMinter(address(this), true, false);
        bobOptimism.updateMinter(address(l2BridgeProxy), true, true);

        vm.selectFork(mainnetFork);

        l1Bridge = new L1BobBridge(l1Messenger, address(l2BridgeProxy), address(bobMainnet), address(bobOptimism));
        l1BridgeProxy.upgradeTo(address(l1Bridge));
        l1Bridge = L1BobBridge(address(l1BridgeProxy));

        vm.selectFork(optimismFork);

        l2Bridge = new L2BobBridge(l2Messenger, address(l1BridgeProxy), address(bobMainnet), address(bobOptimism));
        l2BridgeProxy.upgradeTo(address(l2Bridge));
        l2Bridge = L2BobBridge(address(l2BridgeProxy));

        vm.label(address(bobMainnet), "BOB");
        vm.label(address(bobOptimism), "BOB");
    }

    function _syncL1ToL2State() internal {
        uint256 curFork = vm.activeFork();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        vm.selectFork(optimismFork);
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == bytes32(0xcb0f7ffd78f9aee47a248fae8db181db6eee833039123e026dcbff529522e52a)) {
                vm.prank(address(uint160(l1Messenger) + uint160(0x1111000000000000000000000000000000001111)));
                address to = address(uint160(uint256(logs[i].topics[1])));
                (address from, bytes memory data, uint256 nonce, uint256 gasLimit) =
                    abi.decode(logs[i].data, (address, bytes, uint256, uint256));
                IMessageRelay(l2Messenger).relayMessage(to, from, data, nonce);
            }
        }
        vm.selectFork(curFork);
    }

    function _syncL2ToL1State() internal {
        uint256 curFork = vm.activeFork();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        vm.selectFork(mainnetFork);
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == bytes32(0xcb0f7ffd78f9aee47a248fae8db181db6eee833039123e026dcbff529522e52a)) {
                vm.etch(l1Messenger, "");
                vm.prank(l1Messenger);
                address to = address(uint160(uint256(logs[i].topics[1])));
                (address from, bytes memory data, uint256 nonce, uint256 gasLimit) =
                    abi.decode(logs[i].data, (address, bytes, uint256, uint256));
                vm.mockCall(
                    l1Messenger,
                    abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector),
                    abi.encode(from)
                );
                (bool status,) = to.call{gas: gasLimit}(data);
            }
        }
        vm.selectFork(curFork);
    }

    function testBridgeToOptimism() public {
        vm.selectFork(mainnetFork);

        bobMainnet.mint(user1, 100 ether);

        vm.startPrank(user1);
        bobMainnet.approve(address(l1Bridge), 10 ether);
        vm.expectEmit(true, true, true, true, address(l1Bridge));
        emit ERC20DepositInitiated(address(bobMainnet), address(bobOptimism), user1, user2, 10 ether, "");
        vm.recordLogs();
        l1Bridge.depositERC20To(address(bobMainnet), address(bobOptimism), user2, 10 ether, 1000000, "");
        vm.stopPrank();

        vm.expectEmit(true, true, true, true, address(l2Bridge));
        emit DepositFinalized(address(bobMainnet), address(bobOptimism), user1, user2, 10 ether, "");
        _syncL1ToL2State();

        assertEq(bobMainnet.totalSupply(), 90 ether);
        assertEq(bobMainnet.balanceOf(user1), 90 ether);

        vm.selectFork(optimismFork);

        assertEq(bobOptimism.totalSupply(), 10 ether);
        assertEq(bobOptimism.balanceOf(user2), 10 ether);
    }

    function testBridgeFromOptimism() public {
        vm.selectFork(optimismFork);

        bobOptimism.mint(user2, 100 ether);

        vm.startPrank(user2);
        bobOptimism.approve(address(l2Bridge), 10 ether);
        vm.expectEmit(true, true, true, true, address(l2Bridge));
        emit WithdrawalInitiated(address(bobMainnet), address(bobOptimism), user2, user1, 10 ether, "");
        vm.recordLogs();
        l2Bridge.withdrawTo(address(bobOptimism), user1, 10 ether, 1000000, "");
        vm.stopPrank();

        vm.expectEmit(true, true, true, true, address(l1Bridge));
        emit ERC20WithdrawalFinalized(address(bobMainnet), address(bobOptimism), user2, user1, 10 ether, "");
        _syncL2ToL1State();

        vm.selectFork(mainnetFork);

        assertEq(bobMainnet.totalSupply(), 10 ether);
        assertEq(bobMainnet.balanceOf(user1), 10 ether);

        vm.selectFork(optimismFork);

        assertEq(bobOptimism.totalSupply(), 90 ether);
        assertEq(bobOptimism.balanceOf(user2), 90 ether);
    }
}
