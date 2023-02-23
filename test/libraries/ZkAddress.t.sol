// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../shared/Env.t.sol";
import "../../src/libraries/ZkAddress.sol";

contract ZkAddressTest is Test {
    function testZkAddressDecoding() public {
        vm.expectRevert(ZkAddress.InvalidZkAddressLength.selector);
        ZkAddress.parseZkAddress(
            hex"da9ee1b1b651c87a76c2efe3e4b9b0a0e53e5b66ed19ad100afe5289ea732bfd5ac002969523f26e6f2ff4e1d3", 0
        );
        vm.expectRevert(ZkAddress.InvalidZkAddressChecksum.selector);
        ZkAddress.parseZkAddress(
            hex"da9ee1b1b651c87a76c2efe3e4b9b0a0e53e5b66ed19ad100afe5289ea732bfd5ac002969523f26e6f2ff4e1d3a0", 0
        );
        vm.expectRevert(ZkAddress.InvalidZkAddressLength.selector);
        ZkAddress.parseZkAddress(string("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mriHfN1111"), 0);
        vm.expectRevert(ZkAddress.InvalidZkAddressLength.selector);
        ZkAddress.parseZkAddress(bytes("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mriHfN1111"), 0);
        vm.expectRevert(ZkAddress.InvalidZkAddressChecksum.selector);
        ZkAddress.parseZkAddress(string("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mriHf1"), 0);
        vm.expectRevert(ZkAddress.InvalidZkAddressChecksum.selector);
        ZkAddress.parseZkAddress(bytes("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mriHf1"), 0);
        vm.expectRevert(ZkAddress.InvalidZkAddressLength.selector);
        ZkAddress.parseZkAddress(hex"da9ee1b1b651c87a76c2efe3e4b9b0a0e53e5b66", 0);
        vm.expectRevert(ZkAddress.InvalidZkAddressLength.selector);
        ZkAddress.parseZkAddress(string("QsnTijXe"), 0);
        vm.expectRevert(ZkAddress.InvalidZkAddressLength.selector);
        ZkAddress.parseZkAddress(bytes("QsnTijXe"), 0);

        ZkAddress.ZkAddress memory expected = ZkAddress.ZkAddress(
            bytes10(0xc2767ac851b6b1e19eda), bytes32(0x2f6f6ef223959602c05afd2b73ea8952fe0a10ad19ed665b3ee5a0b0b9e4e3ef)
        );
        ZkAddress.ZkAddress memory actual;

        actual = ZkAddress.parseZkAddress(
            hex"c2767ac851b6b1e19eda2f6f6ef223959602c05afd2b73ea8952fe0a10ad19ed665b3ee5a0b0b9e4e3ef", 0
        );
        assertEq(actual.diversifier, expected.diversifier);
        assertEq(actual.pk, expected.pk);
        actual = ZkAddress.parseZkAddress(abi.encode(expected), 0);
        assertEq(actual.diversifier, expected.diversifier);
        assertEq(actual.pk, expected.pk);

        // generic checksum
        actual = ZkAddress.parseZkAddress(
            hex"da9ee1b1b651c87a76c2efe3e4b9b0a0e53e5b66ed19ad100afe5289ea732bfd5ac002969523f26e6f2ff4e1d3a9", 0
        );
        assertEq(actual.diversifier, expected.diversifier);
        assertEq(actual.pk, expected.pk);
        actual = ZkAddress.parseZkAddress(string("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mriHfN"), 0);
        assertEq(actual.diversifier, expected.diversifier);
        assertEq(actual.pk, expected.pk);
        actual = ZkAddress.parseZkAddress(bytes("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mriHfN"), 0);
        assertEq(actual.diversifier, expected.diversifier);
        assertEq(actual.pk, expected.pk);
        actual = ZkAddress.parseZkAddress(
            hex"da9ee1b1b651c87a76c2efe3e4b9b0a0e53e5b66ed19ad100afe5289ea732bfd5ac002969523f26e6f2ff4e1d3a9", 1
        );
        assertEq(actual.diversifier, expected.diversifier);
        assertEq(actual.pk, expected.pk);
        actual = ZkAddress.parseZkAddress(string("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mriHfN"), 1);
        assertEq(actual.diversifier, expected.diversifier);
        assertEq(actual.pk, expected.pk);
        actual = ZkAddress.parseZkAddress(bytes("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mriHfN"), 1);
        assertEq(actual.diversifier, expected.diversifier);
        assertEq(actual.pk, expected.pk);

        // pool specific checksum
        actual = ZkAddress.parseZkAddress(
            hex"da9ee1b1b651c87a76c2efe3e4b9b0a0e53e5b66ed19ad100afe5289ea732bfd5ac002969523f26e6f2ff9ddd34b", 0
        );
        assertEq(actual.diversifier, expected.diversifier);
        assertEq(actual.pk, expected.pk);
        actual = ZkAddress.parseZkAddress(string("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mz6t7k"), 0);
        assertEq(actual.diversifier, expected.diversifier);
        assertEq(actual.pk, expected.pk);
        actual = ZkAddress.parseZkAddress(bytes("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mz6t7k"), 0);
        assertEq(actual.diversifier, expected.diversifier);
        assertEq(actual.pk, expected.pk);
        vm.expectRevert(ZkAddress.InvalidZkAddressChecksum.selector);
        actual = ZkAddress.parseZkAddress(
            hex"da9ee1b1b651c87a76c2efe3e4b9b0a0e53e5b66ed19ad100afe5289ea732bfd5ac002969523f26e6f2ff9ddd34b", 1
        );
        vm.expectRevert(ZkAddress.InvalidZkAddressChecksum.selector);
        actual = ZkAddress.parseZkAddress(string("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mz6t7k"), 1);
        vm.expectRevert(ZkAddress.InvalidZkAddressChecksum.selector);
        actual = ZkAddress.parseZkAddress(bytes("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mz6t7k"), 1);

        // value outside of prime field
        vm.expectRevert(ZkAddress.InvalidZkAddress.selector);
        ZkAddress.parseZkAddress(string("2zJzzWpuBV9Ag8NQ6kwF8sygXSu4afDn1YfFifb3AxFjdYWsSgE4rkWKYVtTHCg"), 0);
        vm.expectRevert(ZkAddress.InvalidZkAddress.selector);
        ZkAddress.parseZkAddress(bytes("2zJzzWpuBV9Ag8NQ6kwF8sygXSu4afDn1YfFifb3AxFjdYWsSgE4rkWKYVtTHCg"), 0);
        vm.expectRevert(ZkAddress.InvalidZkAddress.selector);
        ZkAddress.parseZkAddress(
            hex"112233445566778899aa010000F093F5E1439170B97948E833285D588181B64550B829A031E1724E64302df800da", 0
        );
        vm.expectRevert(ZkAddress.InvalidZkAddress.selector);
        ZkAddress.parseZkAddress(
            hex"aa99887766554433221130644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001", 0
        );
        vm.expectRevert(ZkAddress.InvalidZkAddress.selector);
        ZkAddress.parseZkAddress(
            abi.encode(
                bytes10(0xaa998877665544332211),
                bytes32(0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001)
            ),
            0
        );
    }
}
