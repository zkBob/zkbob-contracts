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
        ZkAddress.parseZkAddress("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mriHfN1111", 0);
        vm.expectRevert(ZkAddress.InvalidZkAddressChecksum.selector);
        ZkAddress.parseZkAddress("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mriHf1", 0);
        vm.expectRevert(ZkAddress.InvalidZkAddressLength.selector);
        ZkAddress.parseZkAddress(hex"da9ee1b1b651c87a76c2efe3e4b9b0a0e53e5b66", 0);
        vm.expectRevert(ZkAddress.InvalidZkAddressLength.selector);
        ZkAddress.parseZkAddress("QsnTijXe", 0);

        ZkAddress.ZkAddress memory expected = ZkAddress.ZkAddress(
            bytes10(0xda9ee1b1b651c87a76c2), bytes32(0xefe3e4b9b0a0e53e5b66ed19ad100afe5289ea732bfd5ac002969523f26e6f2f)
        );
        ZkAddress.ZkAddress memory actual;

        actual = ZkAddress.parseZkAddress(
            hex"da9ee1b1b651c87a76c2efe3e4b9b0a0e53e5b66ed19ad100afe5289ea732bfd5ac002969523f26e6f2f", 0
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
        actual = ZkAddress.parseZkAddress("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mriHfN", 0);
        assertEq(actual.diversifier, expected.diversifier);
        assertEq(actual.pk, expected.pk);
        actual = ZkAddress.parseZkAddress(
            hex"da9ee1b1b651c87a76c2efe3e4b9b0a0e53e5b66ed19ad100afe5289ea732bfd5ac002969523f26e6f2ff4e1d3a9", 1
        );
        assertEq(actual.diversifier, expected.diversifier);
        assertEq(actual.pk, expected.pk);
        actual = ZkAddress.parseZkAddress("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mriHfN", 1);
        assertEq(actual.diversifier, expected.diversifier);
        assertEq(actual.pk, expected.pk);

        // pool specific checksum
        actual = ZkAddress.parseZkAddress(
            hex"da9ee1b1b651c87a76c2efe3e4b9b0a0e53e5b66ed19ad100afe5289ea732bfd5ac002969523f26e6f2ff9ddd34b", 0
        );
        assertEq(actual.diversifier, expected.diversifier);
        assertEq(actual.pk, expected.pk);
        actual = ZkAddress.parseZkAddress("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mz6t7k", 0);
        assertEq(actual.diversifier, expected.diversifier);
        assertEq(actual.pk, expected.pk);
        vm.expectRevert(ZkAddress.InvalidZkAddressChecksum.selector);
        actual = ZkAddress.parseZkAddress(
            hex"da9ee1b1b651c87a76c2efe3e4b9b0a0e53e5b66ed19ad100afe5289ea732bfd5ac002969523f26e6f2ff9ddd34b", 1
        );
        vm.expectRevert(ZkAddress.InvalidZkAddressChecksum.selector);
        actual = ZkAddress.parseZkAddress("QsnTijXekjRm9hKcq5kLNPsa6P4HtMRrc3RxVx3jsLHeo2AiysYxVJP86mz6t7k", 1);
    }
}
