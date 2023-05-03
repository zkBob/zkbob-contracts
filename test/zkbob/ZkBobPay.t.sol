// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "forge-std/Test.sol";
import "../shared/Env.t.sol";
import "../shared/ForkTests.t.sol";
import "../../src/zkbob/periphery/ZkBobPay.sol";

contract ZkBobPayTest is AbstractPolygonForkTest {
    ZkBobPay pay;
    address constant bob = 0xB0B195aEFA3650A6908f15CdaC7D92F8a5791B0B;
    address constant frax = 0x45c32fA6DF82ead1e2EF74d17b76547EDdFaFF89;
    address constant usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address constant wmatic = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address constant queue = 0x668c5286eAD26fAC5fa944887F9D2F20f7DDF289;
    address constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant oneInchRouter = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    bytes constant zkAddress =
        hex"da9ee1b1b651c87a76c2efe3e4b9b0a0e53e5b66ed19ad100afe5289ea732bfd5ac002969523f26e6f2ff9ddd34b";
    bytes constant note = "zkBob";

    bytes32 constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );
    bytes32 constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH = keccak256(
        "TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)"
    );

    event Pay(uint256 indexed id, address indexed sender, bytes receiver, uint256 amount, address inToken, bytes note);

    function setUp() public {
        vm.createSelectFork(forkRpcUrl, 42000000);

        pay = new ZkBobPay(bob, queue, permit2, oneInchRouter, user2);
    }

    function testPaymentWithBOB() public {
        deal(bob, address(user1), 100 ether);

        vm.prank(user1);
        vm.expectEmit(false, true, false, true);
        emit Pay(0, user1, zkAddress, 100 ether, bob, note);
        IERC677(bob).transferAndCall(address(pay), 100 ether, abi.encode(zkAddress, note));
    }

    function testPaymentWithFRAXUsingEIP2612Permit() public {
        deal(frax, address(user1), 105 ether);

        bytes memory oneInchData =
            hex"12aa3caf000000000000000000000000b97cd69145e5a9357b2acd6af6c5076380f17afb00000000000000000000000045c32fa6df82ead1e2ef74d17b76547eddfaff89000000000000000000000000b0b195aefa3650a6908f15cdac7d92f8a5791b0b000000000000000000000000b97cd69145e5a9357b2acd6af6c5076380f17afb0000000000000000000000005615deb798bb3e4dfa0139dfa1b3d433cc23b72f000000000000000000000000000000000000000000000005b12aefafa80400000000000000000000000000000000000000000000000000059d1a94bf029674000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012f0000000000000000000000000000000000000000000000000001110000e300a007e5c0d20000000000000000000000000000000000000000000000000000bf00004f02a000000000000000000000000000000000000000000000000000000000062c3d20ee63c1e500beaf7156ba07c3df8fac42e90188c5a752470db745c32fa6df82ead1e2ef74d17b76547eddfaff89512025e6505297b44f4817538fb2d91b88e1cf841b542791bca1f2de4661ed88a30c99a7a9449aa841740024cce7ec130000000000000000000000002791bca1f2de4661ed88a30c99a7a9449aa84174000000000000000000000000000000000000000000000000000000000000000080a06c4eca27b0b195aefa3650a6908f15cdac7d92f8a5791b0b1111111254eeb25477b68fb85ed929f73a9605820000000000000000000000000000000000cfee7c08";
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = _digestEIP2612Permit(frax, user1, address(pay), 105 ether, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk1, digest);
        bytes memory permit = abi.encode(0, deadline, r, (v == 28 ? 2 ** 255 : 0) + uint256(s));
        vm.prank(user1);
        vm.expectEmit(false, true, false, true);
        emit Pay(0, user1, zkAddress, 100 ether, frax, note);
        pay.pay(zkAddress, frax, 105 ether, 100 ether, permit, oneInchData, note);

        assertGt(IERC20(bob).balanceOf(address(pay)), 1 ether);
        assertLt(IERC20(bob).balanceOf(address(pay)), 10 ether);
    }

    function testPaymentWithUSDCUsingPolygonPermit() public {
        deal(usdc, address(user1), 105 * 1e6);

        bytes memory oneInchData =
            hex"12aa3caf000000000000000000000000b97cd69145e5a9357b2acd6af6c5076380f17afb0000000000000000000000002791bca1f2de4661ed88a30c99a7a9449aa84174000000000000000000000000b0b195aefa3650a6908f15cdac7d92f8a5791b0b000000000000000000000000b97cd69145e5a9357b2acd6af6c5076380f17afb0000000000000000000000005615deb798bb3e4dfa0139dfa1b3d433cc23b72f0000000000000000000000000000000000000000000000000000000006422c40000000000000000000000000000000000000000000000005a27b0ae42fe74000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bc00000000000000000000000000000000000000000000000000009e000070512025e6505297b44f4817538fb2d91b88e1cf841b542791bca1f2de4661ed88a30c99a7a9449aa841740024cce7ec130000000000000000000000002791bca1f2de4661ed88a30c99a7a9449aa84174000000000000000000000000000000000000000000000000000000000000000080a06c4eca27b0b195aefa3650a6908f15cdac7d92f8a5791b0b1111111254eeb25477b68fb85ed929f73a96058200000000cfee7c08";
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = 0x11223344;
        bytes32 digest = _digestPolygonPermit(usdc, user1, address(pay), 105 * 1e6, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk1, digest);
        bytes memory permit = abi.encode(nonce, deadline, r, (v == 28 ? 2 ** 255 : 0) + uint256(s));
        vm.prank(user1);
        vm.expectEmit(false, true, false, true);
        emit Pay(0, user1, zkAddress, 100 ether, usdc, note);
        pay.pay(zkAddress, usdc, 105 * 1e6, 100 ether, permit, oneInchData, note);

        assertGt(IERC20(bob).balanceOf(address(pay)), 1 ether);
        assertLt(IERC20(bob).balanceOf(address(pay)), 10 ether);
    }

    function testPaymentWithWETHUsingPermit2() public {
        deal(wmatic, address(user1), 105 ether);

        vm.prank(user1);
        IERC20(wmatic).approve(permit2, type(uint256).max);

        bytes memory oneInchData =
            hex"12aa3caf000000000000000000000000b97cd69145e5a9357b2acd6af6c5076380f17afb0000000000000000000000000d500b1d8e8ef31e21c99d1db9a6444d3adf1270000000000000000000000000b0b195aefa3650a6908f15cdac7d92f8a5791b0b000000000000000000000000b97cd69145e5a9357b2acd6af6c5076380f17afb0000000000000000000000005615deb798bb3e4dfa0139dfa1b3d433cc23b72f000000000000000000000000000000000000000000000005b12aefafa804000000000000000000000000000000000000000000000000000596c0743e3441ac05000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f40000000000000000000000000000000000000000000000000000000000d600a007e5c0d20000000000000000000000000000000000000000000000000000b200006302a0000000000000000000000000000000000000000000000000000000000624ada2ee63c1e5819b08288c3be4f62bbf8d1c20ac9c5e6f9467d8b70d500b1d8e8ef31e21c99d1db9a6444d3adf1270b03d578c1ac94c6010f159b29f29bbe204bc70a200a0c028b46d07b03d578c1ac94c6010f159b29f29bbe204bc70a200000000000000000000000000000000000000000000000596c0743e3441ac051111111254eeb25477b68fb85ed929f73a960582000000000000000000000000cfee7c08";
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = 0x11223344 + 2 ** 248;
        bytes32 digest = _digestPermit2(wmatic, address(pay), 105 ether, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk1, digest);
        bytes memory permit = abi.encode(nonce, deadline, r, (v == 28 ? 2 ** 255 : 0) + uint256(s));
        vm.prank(user1);
        vm.expectEmit(false, true, false, true);
        emit Pay(0, user1, zkAddress, 100 ether, wmatic, note);
        pay.pay(zkAddress, wmatic, 105 ether, 100 ether, permit, oneInchData, note);

        assertGt(IERC20(bob).balanceOf(address(pay)), 1 ether);
        assertLt(IERC20(bob).balanceOf(address(pay)), 10 ether);
    }

    function testPaymentWithETH() public {
        deal(address(user1), 105 ether);

        bytes memory oneInchData =
            hex"12aa3caf000000000000000000000000b97cd69145e5a9357b2acd6af6c5076380f17afb000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000000000000000000000000b0b195aefa3650a6908f15cdac7d92f8a5791b0b000000000000000000000000b97cd69145e5a9357b2acd6af6c5076380f17afb0000000000000000000000005615deb798bb3e4dfa0139dfa1b3d433cc23b72f000000000000000000000000000000000000000000000005b12aefafa804000000000000000000000000000000000000000000000000000595c178fbe302e5020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000038600000000000000000000000000000000000000000000000000000000036800a007e5c0d20000000000000000000000000000000000000003440002cd0002b300001a40410d500b1d8e8ef31e21c99d1db9a6444d3adf1270d0e30db000a0860a32ec000000000000000000000000000000000000000000000005b12aefafa8040000000270512072550597dc0b2e0bec24e116add353599eff2e350d500b1d8e8ef31e21c99d1db9a6444d3adf127000e4f0210929000000000000000000000000000000000000000000000000000000000000002000000000000000000000000055443e8dffb64c5b2127f4211e79460a142cff02000000000000000000000000ce8bfa6d1084b09d1765342974539cbaf0d761cc000000000000000000000000b97cd69145e5a9357b2acd6af6c5076380f17afb0000000000000000000000005615deb798bb3e4dfa0139dfa1b3d433cc23b72f0000000000000000000000000d500b1d8e8ef31e21c99d1db9a6444d3adf1270000000000000000000000000c2132d05d31c914a87c6611c10748aeb04b58e8f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005b12aefafa80400000000000000000000000000000000000000000000000000000000000006334c4500000000000000000000000000000000000000000000000000000000645242bb00000000000000000000000000000000000000000000000000000187e154379e0267616e64616c6674686562726f776e67786d786e69001882ed4f9ee8be000000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000041bcd1b8351171df52e5a39acf602704af607a145a480e4bdb2fb1858b40d08c8d6f3e4d0ddb419f52b8e5d3021ba3aa367d62d43ef67e6e236e1e46114a84c1101c000000000000000000000000000000000000000000000000000000000012340020d6bdbf78c2132d05d31c914a87c6611c10748aeb04b58e8f0ca0c2132d05d31c914a87c6611c10748aeb04b58e8fb03d578c1ac94c6010f159b29f29bbe204bc70a2c028b46d07b03d578c1ac94c6010f159b29f29bbe204bc70a200000000000000000000000000000000000000000000000595c178fbe302e5021111111254eeb25477b68fb85ed929f73a9605820000000000000000000000000000000000000000000000000000cfee7c08";
        vm.prank(user1);
        vm.expectEmit(false, true, false, true);
        emit Pay(0, user1, zkAddress, 100 ether, address(0), note);
        pay.pay{value: 105 ether}(zkAddress, address(0), 0, 100 ether, "", oneInchData, note);

        assertGt(IERC20(bob).balanceOf(address(pay)), 1 ether);
        assertLt(IERC20(bob).balanceOf(address(pay)), 10 ether);
    }

    function testCollect() public {
        deal(bob, address(pay), 100 ether);
        deal(frax, address(pay), 100 ether);
        deal(usdc, address(pay), 100 * 1e6);
        deal(wmatic, address(pay), 100 ether);
        deal(address(pay), 100 ether);

        vm.prank(user2);
        address[] memory tokens = new address[](5);
        tokens[0] = bob;
        tokens[1] = frax;
        tokens[2] = usdc;
        tokens[3] = wmatic;
        tokens[4] = address(0);
        pay.collect(tokens);

        assertGe(IERC20(bob).balanceOf(user2), 100 ether);
        assertGe(IERC20(frax).balanceOf(user2), 100 ether);
        assertGe(IERC20(usdc).balanceOf(user2), 100 * 1e6);
        assertGe(IERC20(wmatic).balanceOf(user2), 100 ether);
        assertGe(user2.balance, 100 ether);
    }

    function _digestEIP2612Permit(
        address _token,
        address _holder,
        address _spender,
        uint256 _value,
        uint256 _expiry
    )
        internal
        returns (bytes32)
    {
        uint256 nonce = IERC20Permit(_token).nonces(_holder);
        return ECDSA.toTypedDataHash(
            IERC20Permit(_token).DOMAIN_SEPARATOR(),
            keccak256(abi.encode(IERC20Permit(_token).PERMIT_TYPEHASH(), _holder, _spender, _value, nonce, _expiry))
        );
    }

    function _digestPolygonPermit(
        address _token,
        address _holder,
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 _expiry
    )
        internal
        returns (bytes32)
    {
        return ECDSA.toTypedDataHash(
            IERC20Permit(_token).DOMAIN_SEPARATOR(),
            keccak256(abi.encode(TRANSFER_WITH_AUTHORIZATION_TYPEHASH, _holder, _spender, _value, 0, _expiry, _nonce))
        );
    }

    function _digestPermit2(
        address _token,
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 _expiry
    )
        internal
        returns (bytes32)
    {
        return ECDSA.toTypedDataHash(
            IPermit2(permit2).DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    PERMIT_TRANSFER_FROM_TYPEHASH,
                    keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, _token, _value)),
                    _spender,
                    _nonce,
                    _expiry
                )
            )
        );
    }
}
