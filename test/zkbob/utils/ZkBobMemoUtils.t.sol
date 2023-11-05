// SPDX-License-Identifier: MIT 
pragma solidity "0.8.15";

import "forge-std/Test.sol";
import "forge-std/console2.sol";

contract ZkBobMemoUtilsTest is Test {


    function test_parse_memo() external view {

        bytes memory memo = new bytes(38); //2+8+8+20

        bytes20 proxyAddress = bytes20(msg.sender);

        bytes2 txType = hex"0000";
        bytes8 proxy_fee = hex"0000000000000000";
        bytes8 prover_fee = hex"0000000000000000";

        // New memo struct
        // 0-2 bytes - tx type?
        // 2-22 bytes - proxy address
        // 22-30 bytes - proxy fee
        // 30-38 bytes - prover fee
        memo = bytes.concat(txType,proxyAddress, proxy_fee, prover_fee);
        
    }
}