// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../mocks/TransferVerifierMock.sol";
import "../mocks/TreeUpdateVerifierMock.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPool.sol";
import "../../src/BobToken.sol";
import "../../src/zkbob/manager/SimpleOperatorManager.sol";

contract ZkBobPoolTest is Test {
    uint256 private constant initialRoot = 11469701942666298368112882412133877458305516134926649826543144744382391691533;

    address user1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address user2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    ZkBobPool pool;
    BobToken bob;

    function setUp() public {
        EIP1967Proxy bobProxy = new EIP1967Proxy(address(this), address(0xdead));
        BobToken bobImpl = new BobToken(address(bobProxy));
        bobProxy.upgradeTo(address(bobImpl));
        bob = BobToken(address(bobProxy));
        bob.setMinter(address(this));

        EIP1967Proxy poolProxy = new EIP1967Proxy(address(this), address(0xdead));
        ZkBobPool impl =
            new ZkBobPool(1, address(bob), 1e9, 1e9, new TransferVerifierMock(), new TreeUpdateVerifierMock());
        poolProxy.upgradeToAndCall(address(impl), abi.encodeWithSelector(ZkBobPool.initialize.selector, initialRoot));
        pool = ZkBobPool(address(poolProxy));

        pool.setOperatorManager(new SimpleOperatorManager(user1, "https://example.com"));
    }

    function testSimpleTransaction() public {
        bob.mint(address(pool), 1 ether);

        bytes memory data =
            abi.encodePacked(ZkBobPool.transact.selector, _randFR(), _randFR(), uint48(0), uint112(0), int64(-1));
        for (uint256 i = 0; i < 17; i++) {
            data = abi.encodePacked(data, _randFR());
        }
        data = abi.encodePacked(data, uint16(1), uint16(48), uint64(1), _randFR(), bytes8(bytes32(_randFR())));
        vm.prank(user1);
        (bool status, bytes memory returnData) = address(pool).call(data);
        require(status, "transact() reverted");

        assertEq(bob.balanceOf(user1), 1e9);
    }

    function _randFR() private returns (uint256) {
        return uint256(keccak256(abi.encode(gasleft())))
            % 21888242871839275222246405745257275088696311157297823662689037894645226208583;
    }
}
