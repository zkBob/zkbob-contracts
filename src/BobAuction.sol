// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "./interfaces/IBatchAuction.sol";
import "./auction/DutchAuction.sol";
import "./auction/EnglishAuction.sol";
import "./utils/Ownable.sol";
import "./XPBobToken.sol";

contract BobAuction is Ownable {
    uint96 public feeAmount;
    address public feeReceiver;

    uint96 public duration;
    address public manager;

    XPBobToken public immutable xpBobToken;

    DutchAuction public immutable dutch;
    EnglishAuction public immutable english;
    IBatchAuction public immutable batch;

    event NewBobAuction(address indexed provider, uint256 indexed id, address indexed token);

    modifier onlyManager() {
        require(_msgSender() == manager || _isOwner(), "BobAuction: not a manager");
        _;
    }

    constructor(
        uint96 _fee,
        address _feeReceiver,
        address _manager,
        address _xpBobToken,
        address _dutch,
        address _english,
        address _batch
    )
        Ownable()
    {
        _setFee(_fee, _feeReceiver);
        manager = _manager;
        xpBobToken = XPBobToken(_xpBobToken);
        dutch = DutchAuction(_dutch);
        english = EnglishAuction(_english);
        batch = IBatchAuction(_batch);
    }

    function setFee(uint96 _fee, address _feeReceiver) external onlyOwner {
        _setFee(_fee, _feeReceiver);
    }

    function setManager(address _manager) external onlyOwner {
        manager = _manager;
    }

    function setDuration(uint96 _duration) external onlyOwner {
        duration = _duration;
    }

    function _setFee(uint96 _fee, address _feeReceiver) internal {
        if (_fee > 0) {
            require(_fee <= 0.5 ether, "BobAuction: fee too high");
            require(_feeReceiver != address(0), "BobAuction: empty fee receiver");
        }
        feeAmount = _fee;
        feeReceiver = _feeReceiver;
    }

    function startDutchAuction(
        address _token,
        uint256 _amount,
        uint96 _startTime,
        uint96 _tickTime,
        uint128 _startBid,
        uint128 _tickBid
    )
        external
        onlyManager
        returns (uint256)
    {
        require(
            _startTime >= block.timestamp + 1 hours && _startTime < block.timestamp + 1 weeks,
            "BobAuction: invalid start time"
        );

        uint256 amount = _collectProtocolFee(_token, _amount);

        // extra 10% to account for possible fees
        IERC20(_token).approve(address(dutch), amount * 11 / 10);

        uint256 id = dutch.start(
            DutchAuction.AuctionData({
                sellToken: _token,
                bidToken: address(xpBobToken),
                startTime: _startTime,
                finalTime: _startTime + duration,
                fundsReceiver: address(this),
                auctioneer: owner(),
                total: uint96(amount),
                startBid: _startBid,
                finalBid: 1,
                tickTime: _tickTime,
                tickBid: _tickBid,
                status: DutchAuction.Status.New,
                totalSold: 0,
                totalBid: 0,
                allowList: IAllowList(address(0))
            })
        );

        emit NewBobAuction(address(dutch), id, _token);

        return id;
    }

    function claimDutchAuction(uint256 _id) external onlyManager {
        dutch.claim(_id);
        _burnXP();
    }

    function startEnglishAuction(
        address _token,
        uint256 _amount,
        uint96 _startTime,
        uint96 _tickTime,
        uint128 _startBid,
        uint128 _tickBid
    )
        external
        onlyManager
        returns (uint256)
    {
        require(
            _startTime >= block.timestamp + 1 hours && _startTime < block.timestamp + 1 weeks,
            "BobAuction: invalid start time"
        );

        uint256 amount = _collectProtocolFee(_token, _amount);

        IERC20(_token).approve(address(english), amount * 11 / 10);

        uint256 id = english.start(
            EnglishAuction.AuctionData({
                sellToken: _token,
                bidToken: address(xpBobToken),
                startTime: _startTime,
                finalTime: _startTime + duration,
                fundsReceiver: address(this),
                auctioneer: owner(),
                total: uint96(amount),
                startBid: _startBid,
                tickTime: _tickTime,
                tickBid: _tickBid,
                status: EnglishAuction.Status.New,
                currentBidder: address(0),
                currentBid: 0,
                lastBidTime: 0,
                allowList: IAllowList(address(0))
            })
        );

        emit NewBobAuction(address(english), id, _token);

        return id;
    }

    function claimEnglishAuction(uint256 _id) external onlyManager {
        english.claim(_id);
        _burnXP();
    }

    function startBatchAuction(address _token, uint256 _amount, uint96 _minBuyAmount, uint96 _minBidAmount)
        external
        onlyManager
        returns (uint256)
    {
        uint256 amount = _collectProtocolFee(_token, _amount);

        IERC20(_token).approve(address(batch), amount * 11 / 10);

        uint256 id = batch.initiateAuction(
            IERC20(_token),
            IERC20(xpBobToken),
            block.timestamp + duration - 12 hours,
            block.timestamp + duration,
            uint96(amount),
            _minBuyAmount,
            _minBidAmount,
            0,
            false,
            address(0),
            ""
        );

        emit NewBobAuction(address(batch), id, _token);

        return id;
    }

    function claimBatchAuction(uint256 _id) external onlyManager {
        if (batch.auctionData(_id).clearingPriceOrder == bytes32(0)) {
            batch.settleAuction(_id);
        }
        _burnXP();
    }

    function _collectProtocolFee(address _token, uint256 _amount) internal returns (uint256) {
        uint256 protocolFee = _amount * feeAmount / 1 ether;
        if (protocolFee > 0) {
            IERC20(_token).transfer(feeReceiver, protocolFee);
        }
        return _amount;
    }

    function _burnXP() internal {
        xpBobToken.burn(xpBobToken.balanceOf(address(this)));
    }
}
