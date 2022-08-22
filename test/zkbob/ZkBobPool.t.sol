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

    uint256 pk1 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
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
        ZkBobPool impl = new ZkBobPool(1, address(bob), new TransferVerifierMock(), new TreeUpdateVerifierMock());
        poolProxy.upgradeToAndCall(address(impl), abi.encodeWithSelector(ZkBobPool.initialize.selector, initialRoot));
        pool = ZkBobPool(address(poolProxy));

        pool.setOperatorManager(new SimpleOperatorManager(user2, "https://example.com"));
    }

    function testSimpleTransaction() public {
        bob.mint(address(pool), 1 ether);

        bytes memory data =
            abi.encodePacked(ZkBobPool.transact.selector, _randFR(), _randFR(), uint48(0), uint112(0), int64(-1));
        for (uint256 i = 0; i < 17; i++) {
            data = abi.encodePacked(data, _randFR());
        }
        data = abi.encodePacked(data, uint16(1), uint16(48), uint64(1), _randFR(), bytes8(bytes32(_randFR())));
        vm.prank(user2);
        (bool status, bytes memory returnData) = address(pool).call(data);
        require(status, "transact() reverted");

        vm.prank(user2);
        pool.withdrawFee();
        assertEq(bob.balanceOf(user2), 1e9);
    }

    function testPermitDeposit() public {
        bob.mint(address(user1), 1 ether);

        uint256 expiry = block.timestamp + 1 hours;
        bytes32 nullifier = bytes32(_randFR());
        (uint8 v, bytes32 r, bytes32 s) = _signSaltedPermit(pk1, user1, address(pool), 0.51 ether, 0, expiry, nullifier);
        bytes memory data = abi.encodePacked(
            ZkBobPool.transact.selector, nullifier, _randFR(), uint48(0), uint112(0), int64(0.5 ether / 1 gwei)
        );
        for (uint256 i = 0; i < 17; i++) {
            data = abi.encodePacked(data, _randFR());
        }
        data = abi.encodePacked(
            data,
            uint16(3),
            uint16(80),
            uint64(0.01 ether / 1 gwei),
            uint64(expiry),
            user1,
            bytes32(_randFR()),
            bytes12(bytes32(_randFR()))
        );
        data = abi.encodePacked(data, r, s);
        vm.prank(user2);
        (bool status, bytes memory returnData) = address(pool).call(data);
        require(status, "transact() reverted");

        vm.prank(user2);
        pool.withdrawFee();
        assertEq(bob.balanceOf(user1), 0.49 ether);
        assertEq(bob.balanceOf(address(pool)), 0.5 ether);
        assertEq(bob.balanceOf(user2), 0.01 ether);
    }

    function _signSaltedPermit(
        uint256 _pk,
        address _holder,
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 _expiry,
        bytes32 _salt
    )
        internal
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 digest = ECDSA.toTypedDataHash(
            bob.DOMAIN_SEPARATOR(),
            keccak256(abi.encode(bob.SALTED_PERMIT_TYPEHASH(), _holder, _spender, _value, _nonce, _expiry, _salt))
        );
        return vm.sign(_pk, digest);
    }

    function _randFR() private returns (uint256) {
        return uint256(keccak256(abi.encode(gasleft())))
            % 21888242871839275222246405745257275088696311157297823662689037894645226208583;
    }
}
