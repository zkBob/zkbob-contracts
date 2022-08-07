// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./yield/YieldConnector.sol";
import "./proxy/EIP1967Admin.sol";
import "./utils/Ownable.sol";

/**
 * @title BobVault
 */
contract BobVault is EIP1967Admin, Ownable, YieldConnector {
    using SafeERC20 for IERC20;

    address public yieldAdmin;
    address public investAdmin;
    IERC20 public constant bobToken = IERC20(0xB0B65813DD450B7c98Fed97404fAbAe179A00B0B);

    mapping(address => Collateral) public collateral;

    uint64 internal constant MAX_FEE = 0.01 ether;

    struct Collateral {
        uint128 balance;
        uint128 buffer;
        uint96 dust;
        address yield;
        uint128 price; // X tokens / 1 bob
        uint64 inFee;
        uint64 outFee;
    }

    struct Stat {
        uint256 total;
        uint256 required;
        uint256 farmed;
    }

    event AddCollateral(address indexed token, uint128 price);
    event UpdateFees(address indexed token, uint64 inFee, uint64 outFee);
    event EnableYield(address indexed token, address indexed yield, uint128 buffer, uint96 dust);
    event UpdateYield(address indexed token, address indexed yield, uint128 buffer, uint96 dust);
    event DisableYield(address indexed token, address indexed yield);

    event Invest(address indexed token, address indexed yield, uint256 amount);
    event Withdraw(address indexed token, address indexed yield, uint256 amount);
    event Farm(address indexed token, address indexed yield, uint256 amount);
    event FarmExtra(address indexed token, address indexed yield);

    event Buy(address indexed token, address indexed user, uint256 amountIn, uint256 amountOut);
    event Sell(address indexed token, address indexed user, uint256 amountIn, uint256 amountOut);
    event Swap(address indexed inToken, address outToken, address indexed user, uint256 amountIn, uint256 amountOut);
    event Give(address indexed token, uint256 amount);

    function isCollateral(address _token) external view returns (bool) {
        return collateral[_token].price > 0;
    }

    function stat(address _token) external returns (Stat memory res) {
        Collateral storage token = collateral[_token];
        require(token.price > 0, "BobVault: unsupported collateral");

        res.total = IERC20(_token).balanceOf(address(this));
        res.required = token.balance;
        if (token.yield != address(0)) {
            res.total += _delegateInvestedAmount(token.yield, _token);
            res.required += token.dust;
            res.farmed = res.total - res.required;
        }
        res.farmed = res.total - res.required;
    }

    function addCollateral(address _token, Collateral calldata _collateral) external onlyOwner {
        Collateral storage token = collateral[_token];
        require(token.price == 0, "BobVault: already initialized collateral");

        require(_collateral.price > 0, "BobVault: invalid price");
        require(_collateral.inFee <= MAX_FEE, "BobVault: invalid inFee");
        require(_collateral.outFee <= MAX_FEE, "BobVault: invalid outFee");

        emit UpdateFees(_token, _collateral.inFee, _collateral.outFee);

        (token.price, token.inFee, token.outFee) = (_collateral.price, _collateral.inFee, _collateral.outFee);

        if (_collateral.yield != address(0)) {
            _enableCollateralYield(_token, _collateral.yield, _collateral.buffer, _collateral.dust);
        }

        emit AddCollateral(_token, _collateral.price);
    }

    function enableCollateralYield(address _token, address _yield, uint128 _buffer, uint96 _dust) external onlyOwner {
        Collateral storage token = collateral[_token];
        require(token.price > 0, "BobVault: unsupported collateral");
        require(token.yield == address(0), "BobVault: yield already enabled");

        _enableCollateralYield(_token, _yield, _buffer, _dust);
    }

    function _enableCollateralYield(address _token, address _yield, uint128 _buffer, uint96 _dust) internal {
        Collateral storage token = collateral[_token];

        require(Address.isContract(_yield), "BobVault: yield not a contract");

        (token.buffer, token.dust, token.yield) = (_buffer, _dust, _yield);
        _delegateInitialize(_yield, _token);

        _investExcess(_token, _yield, _buffer);

        emit EnableYield(_token, _yield, _buffer, _dust);
    }

    function disableCollateralYield(address _token) external onlyOwner {
        Collateral storage token = collateral[_token];
        require(token.price > 0, "BobVault: unsupported collateral");
        address yield = token.yield;
        require(yield != address(0), "BobVault: yield not enabled");

        uint256 invested = _delegateInvestedAmount(yield, _token);
        _delegateWithdraw(yield, _token, invested);
        emit Withdraw(_token, yield, invested);

        _delegateExit(yield, _token);
        (token.buffer, token.dust, token.yield) = (0, 0, address(0));
        emit DisableYield(_token, yield);
    }

    function setCollateralFees(address _token, uint64 _inFee, uint64 _outFee) external onlyOwner {
        Collateral storage token = collateral[_token];
        require(token.price > 0, "BobVault: unsupported collateral");

        require(_inFee <= MAX_FEE || _inFee == 1 ether, "BobVault: invalid inFee");
        require(_outFee <= MAX_FEE || _inFee == 1 ether, "BobVault: invalid outFee");

        (token.inFee, token.outFee) = (_inFee, _outFee);

        emit UpdateFees(_token, _inFee, _outFee);
    }

    function setYieldAdmin(address _yieldAdmin) external onlyOwner {
        yieldAdmin = _yieldAdmin;
    }

    function setInvestAdmin(address _investAdmin) external onlyOwner {
        investAdmin = _investAdmin;
    }

    function buy(address _token, uint256 _amount) external returns (uint256) {
        Collateral storage token = collateral[_token];
        require(token.price > 0, "BobVault: unsupported collateral");
        require(token.inFee <= MAX_FEE, "BobVault: collateral deposit suspended");

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        uint256 fee = _amount * uint256(token.inFee) / 1 ether;
        uint256 sellAmount = _amount - fee;
        uint256 buyAmount = sellAmount * 1 ether / token.price;
        token.balance += uint128(sellAmount);

        bobToken.transfer(msg.sender, buyAmount);

        emit Buy(_token, msg.sender, _amount, buyAmount);

        return buyAmount;
    }

    function sell(address _token, uint256 _amount) external returns (uint256) {
        Collateral storage token = collateral[_token];
        require(token.price > 0, "BobVault: unsupported collateral");
        require(token.outFee <= MAX_FEE, "BobVault: collateral withdrawal suspended");

        bobToken.transferFrom(msg.sender, address(this), _amount);

        uint256 buyAmount = _amount * token.price / 1 ether;
        require(token.balance >= buyAmount, "BobVault: insufficient liquidity for collateral");
        unchecked {
            token.balance -= uint128(buyAmount);
        }

        buyAmount -= buyAmount * uint256(token.outFee) / 1 ether;

        _transferOut(_token, msg.sender, buyAmount);

        emit Sell(_token, msg.sender, _amount, buyAmount);

        return buyAmount;
    }

    function swap(address _inToken, address _outToken, uint256 _amount) external returns (uint256) {
        Collateral storage inToken = collateral[_inToken];
        Collateral storage outToken = collateral[_outToken];
        require(inToken.price > 0, "BobVault: unsupported input collateral");
        require(outToken.price > 0, "BobVault: unsupported output collateral");
        require(inToken.inFee <= MAX_FEE, "BobVault: collateral deposit suspended");
        require(outToken.outFee <= MAX_FEE, "BobVault: collateral withdrawal suspended");

        IERC20(_inToken).safeTransferFrom(msg.sender, address(this), _amount);

        // buy virtual bob

        uint256 fee = _amount * uint256(inToken.inFee) / 1 ether;
        uint256 sellAmount = _amount - fee;
        inToken.balance += uint128(sellAmount);
        uint256 bobAmount = sellAmount * 1 ether / inToken.price;

        // sell virtual bob

        uint256 buyAmount = bobAmount * outToken.price / 1 ether;
        require(outToken.balance >= buyAmount, "BobVault: insufficient liquidity for collateral");
        unchecked {
            outToken.balance -= uint128(buyAmount);
        }

        buyAmount -= buyAmount * uint256(outToken.outFee) / 1 ether;

        _transferOut(_outToken, msg.sender, buyAmount);

        emit Swap(_inToken, _outToken, msg.sender, _amount, buyAmount);

        return buyAmount;
    }

    function invest(address _token) external {
        require(_msgSender() == investAdmin || _isOwner(), "BobVault: not authorized");

        Collateral storage token = collateral[_token];
        require(token.price > 0, "BobVault: unsupported collateral");

        _investExcess(_token, token.yield, token.buffer);
    }

    function _investExcess(address _token, address _yield, uint256 _buffer) internal {
        uint256 balance = IERC20(_token).balanceOf(address(this));

        if (balance > _buffer) {
            uint256 value = balance - _buffer;
            _delegateInvest(_yield, _token, value);
            emit Invest(_token, _yield, _buffer);
        }
    }

    function farm(address[] memory _tokens) external returns (uint256[] memory) {
        require(_msgSender() == yieldAdmin || _isOwner(), "BobVault: not authorized");

        uint256[] memory result = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            result[i] = _farm(_tokens[i], msg.sender);
        }
        return result;
    }

    function _farm(address _token, address _to) internal returns (uint256) {
        Collateral storage token = collateral[_token];
        require(token.price > 0, "BobVault: unsupported collateral");

        uint256 currentBalance = IERC20(_token).balanceOf(address(this));
        uint256 requiredBalance = token.balance;

        if (token.yield != address(0)) {
            currentBalance += _delegateInvestedAmount(token.yield, _token);
            requiredBalance += token.dust;
        }

        if (requiredBalance >= currentBalance) {
            return 0;
        }

        uint256 value = currentBalance - requiredBalance;
        _transferOut(_token, _to, value);
        emit Farm(_token, token.yield, value);

        return value;
    }

    function farmExtra(address _token, bytes calldata _data) external {
        require(_msgSender() == yieldAdmin || _isOwner(), "BobVault: not authorized");

        Collateral memory token = collateral[_token];
        require(token.price > 0, "BobVault: unsupported collateral");

        _delegateFarmExtra(token.yield, _token, _msgSender(), _data);

        emit FarmExtra(_token, token.yield);

        assembly {
            returndatacopy(0, 0, returndatasize())
            return(0, returndatasize())
        }
    }

    function give(address _token, uint256 _amount) external {
        Collateral memory token = collateral[_token];
        require(token.price > 0, "BobVault: unsupported collateral");

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        token.balance += uint128(_amount);

        emit Give(_token, _amount);
    }

    function reclaim(address _to, uint256 _value) external onlyOwner {
        uint256 balance = bobToken.balanceOf(address(this));
        uint256 value = balance > _value ? _value : balance;
        if (value > 0) {
            bobToken.transfer(_to, value);
        }
    }

    function _transferOut(address _token, address _to, uint256 _value) internal {
        Collateral storage token = collateral[_token];

        uint256 balance = IERC20(_token).balanceOf(address(this));

        if (_value > balance) {
            address yield = token.yield;
            require(yield != address(0), "BobVault: yield not enabled");

            uint256 invested = _delegateInvestedAmount(yield, _token);
            uint256 withdrawValue = token.buffer + _value - balance;
            if (invested < withdrawValue) {
                withdrawValue = invested;
            }
            _delegateWithdraw(token.yield, _token, withdrawValue);
            emit Withdraw(_token, yield, withdrawValue);
        }

        IERC20(_token).safeTransfer(_to, _value);
    }

    /**
     * @dev Tells if caller is the contract owner.
     * Gives ownership rights to the proxy admin as well.
     * @return true, if caller is the contract owner or proxy admin.
     */
    function _isOwner() internal view override returns (bool) {
        return super._isOwner() || _admin() == _msgSender();
    }
}
