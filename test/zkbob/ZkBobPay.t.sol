// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "forge-std/Test.sol";
import "../shared/Env.t.sol";
import "../shared/ForkTests.t.sol";
import "../../src/zkbob/periphery/ZkBobPay.sol";
import "../../src/proxy/EIP1967Proxy.sol";

contract ZkBobPayTest is AbstractPolygonForkTest {
    ZkBobPay pay;
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
        vm.createSelectFork(forkRpcUrl, 45500000);

        pay = new ZkBobPay(usdc, queue, permit2);
        EIP1967Proxy proxy =
            new EIP1967Proxy(address(this), address(pay), abi.encodeWithSelector(ZkBobPay.initialize.selector));
        pay = ZkBobPay(address(proxy));

        pay.updateFeeReceiver(user2);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = 0xe449022e;
        selectors[1] = 0x12aa3caf;
        pay.updateRouter(oneInchRouter, selectors, true);
    }

    function testPaymentWithUSDC() public {
        deal(usdc, address(user1), 105e6);

        vm.prank(user1);
        IERC20(usdc).approve(address(pay), type(uint256).max);
        vm.prank(user1);
        vm.expectEmit(false, true, false, true);
        emit Pay(0, user1, zkAddress, 100e6, usdc, note);
        pay.pay(zkAddress, usdc, 105e6, 100e6, "", address(0), "", note);

        assertGt(IERC20(usdc).balanceOf(address(pay)), 1e6);
        assertLt(IERC20(usdc).balanceOf(address(pay)), 10e6);
    }

    function testPaymentWithUSDCUsingAuth() public {
        deal(usdc, address(user1), 105e6);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = 0x11223344;
        bytes32 digest = _digestPolygonPermit(usdc, user1, address(pay), 105e6, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk1, digest);
        bytes memory permit = abi.encode(nonce, deadline, r, (v == 28 ? 2 ** 255 : 0) + uint256(s));
        vm.prank(user1);
        vm.expectEmit(false, true, false, true);
        emit Pay(0, user1, zkAddress, 100e6, usdc, note);
        pay.pay(zkAddress, usdc, 105e6, 100e6, permit, address(0), "", note);

        assertGt(IERC20(usdc).balanceOf(address(pay)), 1e6);
        assertLt(IERC20(usdc).balanceOf(address(pay)), 10e6);
    }

    function testPaymentWithFRAXUsingEIP2612Permit() public {
        deal(frax, address(user1), 105 ether);

        bytes memory oneInchData =
            hex"e449022e000000000000000000000000000000000000000000000005b12aefafa804000000000000000000000000000000000000000000000000000000000000062fbe6b00000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000001800000000000000000000000beaf7156ba07c3df8fac42e90188c5a752470db7cfee7c08";
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = _digestEIP2612Permit(frax, user1, address(pay), 105 ether, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk1, digest);
        bytes memory permit = abi.encode(0, deadline, r, (v == 28 ? 2 ** 255 : 0) + uint256(s));
        vm.prank(user1);
        vm.expectEmit(false, true, false, true);
        emit Pay(0, user1, zkAddress, 100e6, frax, note);
        pay.pay(zkAddress, frax, 105 ether, 100e6, permit, oneInchRouter, oneInchData, note);

        assertGt(IERC20(usdc).balanceOf(address(pay)), 1e6);
        assertLt(IERC20(usdc).balanceOf(address(pay)), 10e6);
    }

    function testPaymentWithWETHUsingPermit2() public {
        deal(wmatic, address(user1), 145 ether);

        vm.prank(user1);
        IERC20(wmatic).approve(permit2, type(uint256).max);

        bytes memory oneInchData =
            hex"12aa3caf000000000000000000000000cfd674f8731e801a4a15c1ae31770960e1afded10000000000000000000000000d500b1d8e8ef31e21c99d1db9a6444d3adf12700000000000000000000000002791bca1f2de4661ed88a30c99a7a9449aa841740000000000000000000000001093ced81987bf532c2b7907b2a8525cd0c172950000000000000000000000002e234dae75c793f67a35089c9d99245e1c58470b000000000000000000000000000000000000000000000007dc477bc1cfa4000000000000000000000000000000000000000000000000000000000000063023e70000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005800000000000000000000000000000000000000000000000000000000003a40201093ced81987bf532c2b7907b2a8525cd0c17295bd6015b40000000000000000000000001111111254eeb25477b68fb85ed929f73a9605820000000000000000cfee7c08";
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = 0x11223344 + 2 ** 248;
        bytes32 digest = _digestPermit2(wmatic, address(pay), 145 ether, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk1, digest);
        bytes memory permit = abi.encode(nonce, deadline, r, (v == 28 ? 2 ** 255 : 0) + uint256(s));
        vm.prank(user1);
        vm.expectEmit(false, true, false, true);
        emit Pay(0, user1, zkAddress, 100e6, wmatic, note);
        pay.pay(zkAddress, wmatic, 145 ether, 100e6, permit, oneInchRouter, oneInchData, note);

        assertGt(IERC20(usdc).balanceOf(address(pay)), 1e6);
        assertLt(IERC20(usdc).balanceOf(address(pay)), 10e6);
    }

    function testPaymentWithETH() public {
        deal(address(user1), 145 ether);

        bytes memory oneInchData =
            hex"12aa3caf000000000000000000000000cfd674f8731e801a4a15c1ae31770960e1afded1000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000002791bca1f2de4661ed88a30c99a7a9449aa84174000000000000000000000000cfd674f8731e801a4a15c1ae31770960e1afded10000000000000000000000002e234dae75c793f67a35089c9d99245e1c58470b000000000000000000000000000000000000000000000007dc477bc1cfa4000000000000000000000000000000000000000000000000000000000000063023e70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008600000000000000000000000000000000000000000000000000006800001a40410d500b1d8e8ef31e21c99d1db9a6444d3adf1270d0e30db048201093ced81987bf532c2b7907b2a8525cd0c172950d500b1d8e8ef31e21c99d1db9a6444d3adf1270bd6015b40000000000000000000000001111111254eeb25477b68fb85ed929f73a9605820000000000000000000000000000000000000000000000000000cfee7c08";
        vm.prank(user1);
        vm.expectEmit(false, true, false, true);
        emit Pay(0, user1, zkAddress, 100e6, address(0), note);
        pay.pay{value: 145 ether}(zkAddress, address(0), 0, 100e6, "", oneInchRouter, oneInchData, note);

        assertGt(IERC20(usdc).balanceOf(address(pay)), 1e6);
        assertLt(IERC20(usdc).balanceOf(address(pay)), 10e6);
    }

    function testCollect() public {
        deal(frax, address(pay), 100 ether);
        deal(usdc, address(pay), 100 * 1e6);
        deal(wmatic, address(pay), 100 ether);
        deal(address(pay), 100 ether);

        vm.prank(user2);
        address[] memory tokens = new address[](4);
        tokens[0] = frax;
        tokens[1] = usdc;
        tokens[2] = wmatic;
        tokens[3] = address(0);
        pay.collect(tokens);

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
