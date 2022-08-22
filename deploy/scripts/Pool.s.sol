import "forge-std/Script.sol";
import "../../src/Pool.sol";
import "../../test/mocks/TransferVerifier.sol";
import "../../test/mocks/TreeUpdateVerifier.sol";
import "../../test/mocks/MintableToken.sol";
import "../../test/mocks/PermittableToken.sol";
import "../../src/proxy/ZeroPoolProxy.sol";

import "../../src/utils/SimpleOperatorManager.sol";
import "forge-std/console2.sol";

contract DeployVerifiers is Script {
    function run() external {
        vm.startBroadcast();
        TransferVerifierMock transferVerifier = new TransferVerifierMock();
        TreeUpdateVerifierMock treeVerifier = new TreeUpdateVerifierMock();
        vm.stopBroadcast();
    }
}

contract DeployManager is Script {

    function run() external {
         vm.startBroadcast();
        SimpleOperatorManager simpleOperatorManager = new SimpleOperatorManager(
            0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1
        );
        vm.stopBroadcast();
    }
}

contract DeployPool is Script {
    address private constant vanityAddr =
        address(0xB0B1eda1Df5D4F14Ea631cf462Ba3c029fFC1B0B);

    function run() external {
        vm.startBroadcast();
        PermittableToken token = new PermittableToken(
            "Token",
            "TOKEN",
            0x0000000000000000000000000000000000000000
        );

        
        uint256 initialRoot = 11469701942666298368112882412133877458305516134926649826543144744382391691533; //195B9F09EC42B7282B914B2368569CE69F1589E742B2C25B7D865651EE0CA90D
        int limit = 200;
        uint poolId = 0;
        uint denominator = 1000000000;

        uint256 nonce = vm.getNonce(
            address(0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1)
        );

        IMintable voucherTokenAddress = IMintable(
            0xD833215cBcc3f914bD1C9ece3EE7BF8B14f841bb
        );

        IPermittableToken tokenAddress = IPermittableToken(
            0x9561C133DD8580860B6b7E504bC5Aa500f0f06a7
        );

        Pool pool = new Pool(
            poolId,
            tokenAddress, // TODO: calculate deterministic address based on nonce
            voucherTokenAddress, // TODO: calculate deterministic address based on nonce
            denominator,
            denominator,
            denominator,
            ITransferVerifier(0xe982E462b094850F12AF94d21D470e21bE9D0E9C),
            ITreeVerifier(0x59d3631c86BbE35EF041872d502F218A39FBa150),
            IOperatorManager(0x0290FB167208Af455bB137780163b7B7a9a10C16),
            uint256 (11469701942666298368112882412133877458305516134926649826543144744382391691533),
            200
        );

        address nonce0 = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xd6),
                            bytes1(0x94),
                            0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1,
                            bytes1(0x80)
                        )
                    )
                )
            )
        );

    
        // ZeroPoolProxy poolProxy = new ZeroPoolProxy(
        //     pool,
        //     0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1, // TODO: proxy admin
        //     "0x8129fc1c"
        // );

        // MintableToken voucherToken = new MintableToken(
        //     "Voucher Token",
        //     "VOUCHER",
        //     poolProxy
        // );

        vm.stopBroadcast();
    }
}
