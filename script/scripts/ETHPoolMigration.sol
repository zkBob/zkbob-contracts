// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import "forge-std/Vm.sol";
import "./Env.s.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/zkbob/ZkBobPoolETH.sol";
import "../../src/zkbob/ZkBobPoolETHERC4625Extended.sol";
import "../../src/zkbob/ZkBobDirectDepositQueueETH.sol";
import "../../src/zkbob/ZkBobDirectDepositQueueETHERC4626Extended.sol";
import "../../src/interfaces/IATokenVault.sol";
import "../../src/interfaces/IBatchDepositVerifier.sol";
import "../../src/interfaces/ITreeVerifier.sol";
import "../../src/interfaces/ITransferVerifier.sol";

contract ETHPoolMigration is Script, StdCheats {
    ZkBobPoolETH pool = ZkBobPoolETH(payable(0x58320A55bbc5F89E5D0c92108F762Ac0172C5992));
    ZkBobDirectDepositQueueETH queue_proxy = ZkBobDirectDepositQueueETH(0x318e2C1f5f6Ac4fDD5979E73D498342B255fC869);
    address existing_erc4626token = address(0xac190662aD9b53A4E6D4CD321dbf5d3ECD0E29b0);
    address relayer_addr = address(0x65Eb51b16678d57Bb0bB8d160D1b9D0a57880512);
    address owner = address(0x14fc6a1a996A2EB889cF86e5c8cD17323bC85290);
    address deployer = address(0x39F0bD56c1439a22Ee90b4972c16b7868D161981);

    address erc4626token;

    uint256 fork_block = 107_906_981;
    uint256 cp0_block = 107_924_955; // 0x27b6868740c04368b90ae597737720fc64b9faa6d221aec2b104742cd0f425d0
    uint256 cp1_block = 107_925_266; // 0x5085a5c6a89bd68a5a564085527894a533c4480bdab19ff44888a9785dc066e9
    uint256 cp2_block = 107_940_971; // 0x5a30e79b680b12b33da762777d6ceb7ebfb15150b6e23c99c75dbd824260755b
    uint256 cp3_block = 107_941_231; // 0xe6b18f91f25a62935d18ede1afc5fd778c43cd01e93215eb017eb238bfa9a38f
    uint256 cp4_block = 107_941_263; // 0xd8401d9cb8f2a8339e7d4af7e6b9d481d5748baa2a9f4249970b74c9fe77fbb6
    uint256 cp5_block = 107_941_539; // 0xdf6dffd1a077f99e1ddab1371c845bb73476ca4304a9674f307b56d2da63b2fa
    uint256 cp6_block = 107_941_857; // 0x02328fef26ff2af715c010f6acf090eb1e1c81fbf61fcb2089443b514df70879
    uint256 cp7_block = 107_941_905; // 0x882e358c92d5370de33dbbdfcc477ee2335ba5f34c09692d0aee9dcc82b24321
    uint256 cp8_block = 107_942_058; // 0xd539bef2ebd0f40c7ecff7054f5f49745617ba368e6c5a74b862cc23128e6eb3

    address withdrawal_recipient = address(0x911Bb65A13AF3f83cd0b60bf113B644b53D7E438);

    function deployVault() internal {
        uint256 initial_deposit = 1;

        vm.startPrank(address(0x09Df1626110803C7b3b07085Ef1E053494155089));
        address existing_impl = ITransparentUpgradeableProxy(payable(existing_erc4626token)).implementation();
        vm.stopPrank();

        deal(address(IATokenVault(existing_erc4626token).UNDERLYING()), deployer, 1 ether);

        bytes memory data = abi.encodeWithSelector(
            IATokenVault.initialize.selector, owner, 0, "Wrapped aWETH", "waWETH", initial_deposit
        );
        address proxyAddr = computeCreateAddress(deployer, vm.getNonce(deployer));
        vm.startPrank(deployer);
        IERC20(IATokenVault(existing_erc4626token).UNDERLYING()).approve(proxyAddr, initial_deposit);
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(existing_impl, owner, data);
        vm.stopPrank();
        erc4626token = address(proxy);
    }

    function setMocks() internal {
        IBatchDepositVerifier dd_verifier = pool.batch_deposit_verifier();
        ITreeVerifier tree_verifier = pool.tree_verifier();
        ITransferVerifier transfer_verifier = pool.transfer_verifier();

        vm.mockCall(address(dd_verifier), abi.encodeWithSelector(dd_verifier.verifyProof.selector), abi.encode(true));
        vm.mockCall(
            address(tree_verifier), abi.encodeWithSelector(tree_verifier.verifyProof.selector), abi.encode(true)
        );
        vm.mockCall(
            address(transfer_verifier), abi.encodeWithSelector(transfer_verifier.verifyProof.selector), abi.encode(true)
        );
    }

    function migrate() internal {
        ITransferVerifier transferVerifier = pool.transfer_verifier();
        ITreeVerifier treeVerifier = pool.tree_verifier();
        IBatchDepositVerifier batchDepositVerifier = pool.batch_deposit_verifier();
        uint256 pool_id = pool.pool_id();
        require(queue_proxy == pool.direct_deposit_queue(), "Incorrect Direct Depoist queue proxy");

        vm.startPrank(deployer);
        ZkBobPoolETHERC4625Extended poolImpl = new ZkBobPoolETHERC4625Extended(
            pool_id, erc4626token,
            transferVerifier, treeVerifier, batchDepositVerifier,
            address(queue_proxy), address(0x000000000022D473030F116dDEE9F6B43aC78BA3)
        );
        ZkBobDirectDepositQueueETHERC4626Extended queueImpl =
            new ZkBobDirectDepositQueueETHERC4626Extended(address(pool), erc4626token, pool.denominator());
        vm.stopPrank();

        bytes memory migrationData = abi.encodePacked(poolImpl.migrationToERC4626.selector);

        vm.startPrank(owner);
        EIP1967Proxy(payable(address(pool))).upgradeToAndCall(address(poolImpl), migrationData);
        EIP1967Proxy(payable(address(queue_proxy))).upgradeTo(address(queueImpl));
        vm.stopPrank();
    }

    function _makeDD(address _sender, uint256 _amount, bytes memory _zkaddress) internal {
        console.log("***** directNativeDeposit ******");
        console2.log("queue's waWETH before making DD:", IERC20(erc4626token).balanceOf(address(queue_proxy)));
        getAssetsForAccount(address(queue_proxy), "queue's WETH in AAVE before making DD:");
        vm.deal(_sender, _amount + 1 ether);
        vm.startPrank(_sender);
        queue_proxy.directNativeDeposit{value: _amount}(_sender, _zkaddress);
        vm.stopPrank();
        console2.log("queue's waWETH after making DD:", IERC20(erc4626token).balanceOf(address(queue_proxy)));
        getAssetsForAccount(address(queue_proxy), "queue's WETH in AAVE after making DD:");
    }

    function _appendDD(bytes memory _data) internal {
        console.log("***** appendDirectDeposits ******");
        console2.log("pool's waWETH before append DD:", IERC20(erc4626token).balanceOf(address(pool)));
        getAssetsForAccount(address(pool), "pool's WETH in AAVE before append DD:");
        console2.log("queue's waWETH before append DD:", IERC20(erc4626token).balanceOf(address(queue_proxy)));
        getAssetsForAccount(address(queue_proxy), "queue's WETH in AAVE before append DD:");
        vm.startPrank(relayer_addr);
        address(pool).call(abi.encodePacked(pool.appendDirectDeposits.selector, _data));
        vm.stopPrank();
        console2.log("pool's waWETH after append DD:", IERC20(erc4626token).balanceOf(address(pool)));
        getAssetsForAccount(address(pool), "pool's WETH in AAVE after append DD:");
        console2.log("queue's waWETH after append DD:", IERC20(erc4626token).balanceOf(address(queue_proxy)));
        getAssetsForAccount(address(queue_proxy), "queue's WETH in AAVE after append DD:");
    }

    function _transact(bytes memory _data) internal {
        vm.startPrank(relayer_addr);
        address(pool).call(abi.encodePacked(pool.transact.selector, _data));
        vm.stopPrank();
    }

    function _withdrawal(bytes memory _data, address _recipient) internal {
        console.log("***** Withdrawal ******");
        console2.log("pool's waWETH before withdrawal:", IERC20(erc4626token).balanceOf(address(pool)));
        getAssetsForAccount(address(pool), "pool's WETH in AAVE before withdrawal:");
        console2.log("recipient's ETH before withdrawal:", _recipient.balance);
        console2.log(
            "recipient's WETH before withdrawal:", IERC20(IATokenVault(erc4626token).UNDERLYING()).balanceOf(_recipient)
        );
        _transact(_data);
        console2.log("pool's waWETH after withdrawal:", IERC20(erc4626token).balanceOf(address(pool)));
        getAssetsForAccount(address(pool), "pool's WETH in AAVE after withdrawal:");
        console2.log("recipient's ETH after withdrawal:", _recipient.balance);
        console2.log(
            "recipient's WETH after withdrawal:", IERC20(IATokenVault(erc4626token).UNDERLYING()).balanceOf(_recipient)
        );
    }

    function makeDD00() internal {
        bytes memory zk_addr =
            hex"295be91b2e50e257ef37510fae0bfd5f829bd2b787c9c76b851cdfa03121416c8262127ff2bb08871f1f5282ad25";
        _makeDD(address(0xDfb7c410BE17F38Ecb970EFa438Db308CA281e23), 0.0102 * 1 ether, zk_addr);
    }

    function makeDD01() internal {
        bytes memory zk_addr =
            hex"6d2fbd3294102889b87529f244b938632e96c1ad6faf1e3d7173b46029907b9a0fbd39f623a88a42ec2c1612b285";
        _makeDD(address(0xF2186FC0a8Af528FbB51a59f33624d411f2A1011), 0.0052 * 1 ether, zk_addr);
    }

    function makeDD02() internal {
        bytes memory zk_addr =
            hex"93c32cf3b1a2164faca3c7a89afffda32d13455c1b14e194a6eb48ba3e969c2bfa79e9481769d9ff3614eb6dbbd9";
        _makeDD(address(0x5190459d54796004C748DFaf8B579Fa3a5fadb9C), 0.0222 * 1 ether, zk_addr);
    }

    function appendDD00() internal {
        bytes memory data =
            hex"1229766f8050090dd9d1ab7ac58909666384df7307f9b77ee1eabd826631f8ae00000000000000000000000000000000000000000000000000000000000002600c35451ab1dcc062b45a43bc06404ccb93adb7b7e7b591e2cd514e9a2ecbd738119ea6ac237bf5d18cd2f199dff62a7f8c84ae1d166dc15dfa1a937de846c3fa07cdc341c0d2ddc686a404bde5a16f3d43aba410361d3eab8908b10c7680cdf5250c794662dabadbb96ab6146f3811d3261831d509aafa46d50d90c7098f53b80ec87ce11a502cff0a12793abede59901e63f3400721c78a4b4d43844f4ee1e5038b108eef967f58790d1086c6bccc6ac071ab00a4f13d470ecce3b42a3b7ed30892d032528c8ddf899d6aefa14d1cc8b4dcc04bf2712661dc1045a0b693b8360940a258e83f3aadafc90943e0f2609ecc97fbc56a5b9112876d34bd07ba368c106b62d1ae0ad01eeeaf6f82c4c8823b1ad271bd4d722cde62d6746cdd2ccb142363eccc9c277220fa14ace2b3da1c0f1a2111c07d6ebec102325eb022a21d63042e57b2e51b7a210a9516178f32b0f6f8f59c4bcc15fe3ccb3020540be64bb105db736ab173915a7b5b7041840566cd6b46e1b41281b8043de46cf1fd11fb1023d9054d9a3f535c50608724e153d9b965fdf7bfb6875f5ba569a85ac120a6bd235e91e15bfdfd6397b77c7fedcf64e9a70e4b55cbf48b86958db46e542337ae02bafe76929952236e01771bd8b03fea1cec0c31139eca4c79ae0455e4094d9317fb1341b9854e62f5110472f8dbc74a55a3633492fe65e1bcec059253a7126612dde352bcdcaf323a9e00ea6e4eacb4ffe7c2c5249d9318692fd9908d84d9330000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000007b";
        _appendDD(data);
    }

    function appendDD01() internal {
        bytes memory data =
            hex"05d2b48a69cd0ff6ab7b5b5d83ee0785604005265545e4ac273bfff3559055bd000000000000000000000000000000000000000000000000000000000000026028b99bb910641a7bf3f761299cda0c7c27e67e34a823f571dbe0c3a045957d5c0e53e8ee69e0706ad2226c4ffc5fea08c33d7830a75a16fdd9380f8b524272740514173388161082b266a7801cc1c422bf3078f9d6fbcbd408486ef14dae1dd10ceaaf884c0846bffba3d5a6c84cb5c5ddbfc83f4f2222ea803d0ce351256c0f2bf624334ad43cd72e1ac660868d982191457bb7da59e91b7da5ca33a9aac5c02f30988a66cea32a9f1c034e3ac4c1756af1bf003be35d1bf2e16853b02fa7582e55404b5a94af13fdea3ac908b482daa5ce870576fc906ce2cb947f2e4770a314cbf16715f900c2eac88486c12d6a2c01df445860e73c33c29575c60c5880891511071a86af11c467684ce421e7889db6a6eef355761af5e94f6276bc6ecadb23ec574d3a42a8bd37d4b48bfe583f4e781a543cf3346063c08397e5b2a2d98e211db6de87aabab2c1a9b9b78b424f4b5965e9b6fc0452067cdd232c1492fa8130424da6573f186023ebde3e4171a26a513aa76c389e044bd9a46d07a3d5f30200076515a74280ca0b22bca6f06c42e5b47454ac978ada91ea42ab8242d5bac209043871a60f95e82dd92413d9f2f9a3f5d46645d11e70df733045cec2a2415c2a3aa601e044ded6de0648e112fbfacb2189d47abdec7bf3ad3c66828b176c1a23682eea4ec8648c70d34731309c2c00c9620175d7076604ea08c4edd38015a718bdf6d046053fc7c1b885eea1f11bb62213d3cafac45f4870acb8f8b30e9cef0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000007c";
        _appendDD(data);
    }

    function appendDD02() internal {
        bytes memory data =
            hex"1b97f36072d3b1ddee3f08bc8a15cb08d3026a2b96d1ea08aac6f08b1c75452300000000000000000000000000000000000000000000000000000000000002600f9c66f79d6d870cc9a6418c5ced641db497b755e2e6e6bb22d3c386318e751e304eeddc8551fb12d9b4cf060654a3278a0b1d3902ee10d54224f33bd9dbbd60172066dd8c0649988cfd70b4f959f74eef0d262cd28fe35a1d22788821bc459e1b08535bc1cfb97f641379f055c48afce608ef6bba1782c78909216f1d8992d30cb19b1e2c17548d5a3553a7671ef7f719e88e6cfffc7d1478b3f5f6f381d0a217039064b88c5eaceb3961ebf69982f92804fb8fe3e546a6b878b6d43b09b6c31ae4f9ebd70e068831cbf93783d778a0546695052ff990ef3cbbc67fdb9521831e9cc86ee91de2fe70740f8be4f2756a326098a0f5c4c6c8c08e100d650a6bd9091b67bcfb8109af1d0bf8780065efca68d7373e81d1686e27dbcac5094c19092abf02e0ab23c77650bc9a25fed89139df983fa0986c944e586c0ecaed37f7a90b0e3e34983d1f3febc14adefa3965675ab55658d69b5caa54615c88651c57211bdc80d1cb3aef922f9bca2da1ced7aa4b7f55ec7d3658933ca7b2f8637c664109b0b66f5f49cbeffe0636d368b7694e5456bb4d77f36f3860077263142fcdfe1674f2319bcb9b890612db1b32d8ad3d48b6953950100daaa1cf78f1d7cb5417038d438be8876fb407dcc2d93f2bf427ac71ec34f87313d38f384641b76496a32679b187b279045499a38c64c4e324dc9a3c87854d8c49761e5fa190f2beefee0f172e51e682b9f3e72e9324ede8f638b189fa70dc7c4e9df9c3b16c948c561f0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000007d";
        _appendDD(data);
    }

    function makeTransfer00() internal {
        bytes memory data =
            hex"2fef02f323d8ee50178a5259fd223838840a2b0b74bf9e2335a71205a9f47a292b2e499245f33f5f8923e0891a08d3d40abd4d0f60ca41b1d079df51f36315ab00000000b3000000000000000000000000000000fffffffffffb40ad25dad015ebd9dd3ed308613cd79a4e0fa5a6dfc3abb288ad730f10231eae32761ee4fcc4f2b1b452b3c7a42959ec5ce612964b9a94dad781e4458d9fe7a884e30f64cf8c0ac90ba94bc12e9dd531c177c9e1c59dd182f52b150d04b4b10b388a111181435fb6d7d31bc0fb43cf3a0cb99567815cc1943280b7798a9c72d17ff2248f4718b64a31c0ebce3614eac17deba615932ccbd0b7917c02658c6b47827901fed373bf315db08317f6add21fa89418c30aa973e7cee0229b207575b8a8b40fbc6ee49134502a936ec9bca7569dccfad4b5aa4090d015038debc513008ac5281518c2adc5227fa194aa4fdc44c48d93af4ea8c16c894cc8c436c3ad9e57b00caf63277259f4e0e0ec1bd0d3395fc7841bfab08b046e4d0b10a769894fac2a120789e382bc0adc2b721357facd9bfc7ea64b348e14eff5a3a8446da5ff10a0017d2baa9ffe33a841d68b2412b6fed29bbd18cc87697fab5f00136a9bf63b9910fe57ee22a372773c0162df770abee9dc4b6e94434549a56080f16c5117f5de1622aac1e31a4835652cd36104f5f74d5cfb8e8e28d13c4e03306cc8004ede181e9fe82bd1188ccc7bee6bb43e0772d0b6ab503593afccb27556dc487ca3f5482bfdcf2e4063fcf7037de375e8ac219eacc6866aa2988bd2e99d22bb843ac1e903f49b4e91b444fa4cb548beda101fa40147cd948961d075bf6e9183fb0411242beb8715fbff532965e78b5674a9e9f027e2d123c59966f1b08e1e0e7df8ecb10001017e000000000004bf5302000000a359fa71b4169b2d63e34f07ef2b0537ee2dd7e4203ff0cbeebcc20a79a2bd0f67a564399662d37d475e40fe34c9d103c6e846b76a4ece72a9c73eda737a48029049ee33d045e3e070b5a3a1bf9beea4410f0ceffd1115d81490c08e036658071714795aaee1c0da359e70fa225e7510ebbf27f556707bc1f2269e1ce17729a06b74ba9c00b64c9f8267ab53da3de4c201aa610905c38a5ea62a8161ffb4de615a48cf695f5c1689a395f5a1bd084b83816daaced4f798ef7d252a219d41708701ce4df49b0074432aa8217529d2ebfe182a1206413660c375c7c094a206000239d31b62f8a3b430fc6f5dfa8135b17a83601a1146db057d79b8838ed4d95939f409de821c475010bb0fb814e0f923d93e809d32ce1bb40854e403045992bc062e55060f5b156ec2822f3d054732adf7e9b27209adb93c71aa74b331098fe962c122a82e44cc48ded31d02859d815d172befcb5ff78dbce4a8ea6eb4211ac91cb1b0bc62058edad68413cbde1005d6ba4d5f";
        _transact(data);
    }

    function makeWithdrawal00() internal {
        bytes memory data =
            hex"11f8f60c37141d3262197664fae1e9a45b2126bf5591ba6b7cefdf3b571077ca12ef8e582234b82718522c26c7dfa0de2a297dc8aba33d37e6f00cc355891e2400000000b3800000000000000000000000000000fffffffffeb5222d0eafdadb9d8f9665fda9c77bd5d4ea7b447e1af4cfc315692ce5dcebece0e74322f1b3d899d679b870ef1e7d736527919f8c73eb49283bdc94d40f1ec714bdb40fc02233944a3b3427aa2d74775ce5fc8db55495b12b2826286f695c364d68021d98d982433485528b393edbe15635ba2b82a19479cd5f8a5b2e99a317d313dd09ff8692607e7b7ebea7d3132cd92bc629a9188028dd718af3cba8c30d9fd62a1d917a9302b18fb7836ac3782bbf0e1c1c1434cc95b79b2b21eb821554da45ca130cbdc489cedce217c36961c47e305a4d372f4050dfe0459ea2cff77439378825dd60b6d500f79a11f9d4a80149c7c01e6a727553390a2d7e652856b1fa5d7c0571c3c76296ae6e21b332c488aa849e1e5e39583c249084c1480474655103fd08a8858a1d88b8d9a5a5cf5d530fb458a7bc31c9b3e964607d3953624a0921b2004dcd7904d882e20c46252c1bb06479a6c8b6f8eabbccd662641e7b71bca3650554cc01aa7c9e8a185a777cde51c7bd3559cffceb734bb3f84b1d38827472ae0d8e333da0a6b332aa76bfab841ab5e2347417cf646e5b516666608479919912294b931c2cf5916970fc646d9c27ad17ace5432fdd281c5b160b008b67cd61a12a1c794787f654ab6d1d2ef91df36161f68a8b1e6264236b39c03ddbc28023e1280494e31fcef2c88cb7762cec0ea1e08969835f5617be932a343316be8bd7982a37719f6e9f831b5cbdd274d2962ab43c81d4e0bd304f6e6140960615ac9ef7000200ee0000000000043379ffffffffffffffff60784aed2f09a88f6a675335cb7e85bdc47c673601000000339d6506435ecb993a1efc3654e95f51229b7696005f3e16bd82b5eae996d11a764f58df9c9c5afd608f0daad3599cbe4c09d38fe589cd6965948e444b836d139a693bbbdac315b6d13969f01b56d2a7bfdd50fa839a7b2d858a85a78464c64b66feb74f64c5728fbad9a5eb1ab9f1313364fb58be0a35eba8d35c288c47982d44842bfe71ffeedfe64c0f6a97ed7a3630159c58832d931ca6eb8c5f35ebc88fb0d2145a3e7df189cc39f9c3600af2fb9cad370661694c231b9981dd3c6399da0156193ea1cf";
        _withdrawal(data, address(0x60784aeD2F09a88F6A675335CB7E85Bdc47C6736));
    }

    function makeWithdrawal01() internal {
        bytes memory data =
            hex"2a7423032ebbcbc8ee968b95826f2b9a105d546a189a6237784c1f44152da56811227cc542e1a6b30ecb1bdaf217174c07838778bc8c55fdfa7f2cb7af123f6c00000000b4000000000000000000000000000000ffffffffffb3b4c02513607b1e287057fc60e14d44b5401ce3f378c1b112c775add74741c6ae431f0cee37104a3d89158d5ecf2e31c47eaab1a86b8b1a502246a392b0c592c4a9b51e7c82bbbcef54faf4a23347a8c5a9cc7d1096b67d508326ce4f48e3b637dba02e8b37b93330b087d670ab798d7ac15dfdcfb01b31c32ea80da85bc1646e26dd0e4eb7c8714bda5e58c4752211325c617c466e883bb6475ea744d8c2dac1352e098f2e67176efa5f50b0683af9f8aef1b651217f6f872ce601170e670c86298c10bd10885057f90475b80ae839aca8994158d388eb9e39e641a3e399e6df68d02f1bb29f3b14f50e756a1567c906253a3d3fbc052a9b408dd93ca053aa7817e61dd47d019f67af71cd397370317806717c5583df6fd4d65e76ee529c5f3b35531d8992bb1614dc3f3a5de5ceebd20277e636ed6438a336f2a54d9f8ef212914f08519a892a0a625b372150d32523823ca5d20b35840a40e4d79bebc32f1275d10eabc7eb453f26d42545aafecee76f45d44d815594cac30b52540f3fe54ddeee01b0e4b53370980cae38b29601646a02fd32a319f2f43a8bd10f2b75591f9bdb2bbc600756f0e2a88c3f5f8609197a35987769d6b010a9df3f1118546c46e47d0222f3b912a3850d9be5bd4715d04bcfbd6c0fc2c9a929d3892b679a361f71b31416971c27c95c72bbe7fba82aae42bbe3ffdf5f6dbb3ee2dd6d2ec82504eb75037c9d1f7f2fa4aa3c0a7b2e721ef6f0a12e570b5f3df629a5ae3bd30d01c889000200ee0000000000045592fffffffffffffffff2186fc0a8af528fbb51a59f33624d411f2a101101000000fb4adffa24ebb22644820146d7a576fd4c18cf5a51cdbec92248591e010421158160d52e2c69486c38d2f919b09a11ef9548f960710144b5379d30c9bb7e441e5d7ff2958221e454f4b3a4e2f6f5bc441fe0f8557d109ae10a16a41082dccb080e74de767ea5e14205ffc39ca259bf1e4b66e77bcb7f0a3e23faaf3d8d9f9d982e59a4761fe9324b110817cf19e2a7e39783ce5f44e489fa22a343f4a26a08598adaaec10dd57790a2bff1f0dd63530185f88ff37a3dd4250503762251b7d7a0886717624d2e";
        _withdrawal(data, address(0xF2186FC0a8Af528FbB51a59f33624d411f2A1011));
    }

    function getAssetsForAccount(address _owner, string memory _logmsg) internal {
        uint256 shares = IERC20(erc4626token).balanceOf(_owner);
        getAssetsForAccount(shares, _owner, _logmsg);
    }

    function getAssetsForAccount(uint256 _shares, address _owner, string memory _logmsg) internal {
        uint256 amount_out = 0;
        if (_shares != 0) {
            // uint256 snapshot = vm.snapshot();
            // vm.startPrank(_owner);
            // amount_out = IATokenVault(erc4626token).redeem(_shares, _owner, _owner);
            amount_out = IATokenVault(erc4626token).previewRedeem(_shares);
            // vm.stopPrank();
            // vm.revertTo(snapshot);
        }
        console2.log(_logmsg, amount_out);
    }

    function progressChainTo(uint256 _to_block) internal {
        vm.warp(block.timestamp + (_to_block - block.number) * 2);
        vm.roll(_to_block);
    }

    function run() external {
        if (block.number != fork_block) {
            return;
        }

        deployVault();
        setMocks();

        console2.log("WETH before migration:", IERC20(IATokenVault(erc4626token).UNDERLYING()).balanceOf(address(pool)));
        console2.log("waWETH before migration:", IERC20(erc4626token).balanceOf(address(pool)));
        getAssetsForAccount(address(pool), "WETH in AAVE before migration:");

        migrate();

        console2.log("WETH after migration:", IERC20(IATokenVault(erc4626token).UNDERLYING()).balanceOf(address(pool)));
        console2.log("waWETH after migration:", IERC20(erc4626token).balanceOf(address(pool)));
        getAssetsForAccount(address(pool), "WETH in AAVE after migration:");

        // vm.warp(fork_ts + (cp0_block - fork_block) * 2);
        // vm.roll(cp0_block - fork_block);
        progressChainTo(cp0_block);
        makeDD00();

        progressChainTo(cp1_block);
        appendDD00();

        progressChainTo(cp2_block);
        makeDD01();

        progressChainTo(cp3_block);
        makeDD02();

        progressChainTo(cp4_block);
        appendDD01();

        progressChainTo(cp5_block);
        appendDD02();

        progressChainTo(cp6_block);
        makeTransfer00();

        progressChainTo(cp7_block);
        makeWithdrawal00();

        progressChainTo(cp8_block);
        makeWithdrawal01();
    }
}
