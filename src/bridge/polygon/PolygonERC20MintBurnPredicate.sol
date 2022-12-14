// SPDX-License-Identifier: MIT

pragma solidity 0.6.6;

import "@polygon/pos-portal/root/TokenPredicates/ITokenPredicate.sol";

interface IERC20MintBurn {
    function mint(address user, uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address user, uint256 amount) external;
}

/**
 * @title ERC20 Mint/Burn Predicate for Polygon PoS bridge.
 * Works with a `Withdrawn(address account, uint256 value)` event.
 */
contract PolygonERC20MintBurnPredicate is ITokenPredicate {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    event LockedERC20(
        address indexed depositor, address indexed depositReceiver, address indexed rootToken, uint256 amount
    );

    // keccak256("Withdrawn(address account, uint256 value)");
    bytes32 public constant WITHDRAWN_EVENT_SIG = 0x7084f5476618d8e60b11ef0d7d3f06914655adb8793e28ff7f018d4c76d505d5;

    // see https://github.com/maticnetwork/pos-portal/blob/master/contracts/root/RootChainManager/RootChainManager.sol
    address public immutable rootChainManager;

    constructor(address _rootChainManager) public {
        rootChainManager = _rootChainManager;
    }

    /**
     * Burns ERC20 tokens for deposit.
     * @dev Reverts if not called by the manager (RootChainManager).
     * @param depositor Address who wants to deposit tokens.
     * @param depositReceiver Address (address) who wants to receive tokens on child chain.
     * @param rootToken Token which gets deposited.
     * @param depositData ABI encoded amount.
     */
    function lockTokens(
        address depositor,
        address depositReceiver,
        address rootToken,
        bytes calldata depositData
    )
        external
        override
    {
        require(msg.sender == rootChainManager, "Predicate: only manager");
        uint256 amount = abi.decode(depositData, (uint256));
        emit LockedERC20(depositor, depositReceiver, rootToken, amount);
        IERC20MintBurn(rootToken).burnFrom(depositor, amount);
    }

    /**
     * Validates the {Withdrawn} log signature, then mints the correct amount to withdrawer.
     * @dev Reverts if not called only by the manager (RootChainManager).
     * @param rootToken Token which gets withdrawn
     * @param log Valid ERC20 burn log from child chain
     */
    function exitTokens(address, address rootToken, bytes memory log) public override {
        require(msg.sender == rootChainManager, "Predicate: only manager");

        RLPReader.RLPItem[] memory logRLPList = log.toRlpItem().toList();
        RLPReader.RLPItem[] memory logTopicRLPList = logRLPList[1].toList(); // topics

        require(
            bytes32(logTopicRLPList[0].toUint()) == WITHDRAWN_EVENT_SIG, // topic0 is event sig
            "Predicate: invalid signature"
        );

        address withdrawer = address(logTopicRLPList[1].toUint()); // topic1 is from address

        IERC20MintBurn(rootToken).mint(withdrawer, logRLPList[2].toUint());
    }
}
