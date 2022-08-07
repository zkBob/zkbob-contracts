// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../utils/Ownable.sol";
import "../interfaces/IAllowList.sol";

contract DutchAuction is Ownable {
    enum Status {
        New,
        Cancelled,
        Filled,
        PartiallyFilled
    }

    struct AuctionData {
        address sellToken;
        uint96 startTime;
        address bidToken;
        uint96 finalTime;
        address fundsReceiver;
        uint96 tickTime;
        address auctioneer;
        Status status;
        IAllowList allowList;
        uint128 startBid;
        uint128 finalBid;
        uint128 tickBid;
        uint128 total;
        uint128 totalSold;
        uint128 totalBid;
    }

    uint256 public auctionCount;
    mapping(uint256 => AuctionData) internal auctions;

    uint96 public feeAmount;
    address public feeReceiver;

    event NewAuction(uint256 indexed id, address indexed sellToken, address indexed bidToken, AuctionData data);
    event FilledOrder(uint256 indexed id, address indexed user, uint256 bidAmount, uint256 sellAmount);
    event CancelledAuction(uint256 indexed id);
    event FinalizedAuction(uint256 indexed id, uint256 totalBid, uint256 totalSold);

    constructor(uint96 _fee, address _feeReceiver) Ownable() {
        _setFee(_fee, _feeReceiver);
    }

    function setFee(uint96 _fee, address _feeReceiver) external onlyOwner {
        _setFee(_fee, _feeReceiver);
    }

    function _setFee(uint96 _fee, address _feeReceiver) internal {
        if (_fee > 0) {
            require(_fee <= 0.02 ether, "DutchAuction: fee too high");
            require(_feeReceiver != address(0), "DutchAuction: empty fee receiver");
        }
        feeAmount = _fee;
        feeReceiver = _feeReceiver;
    }

    function auctionData(uint256 _id) external view returns (AuctionData memory) {
        return auctions[_id];
    }

    function start(AuctionData memory _data) external returns (uint256) {
        require(_data.status == Status.New, "DutchAuction: not new");
        require(_data.total > 0, "DutchAuction: non-zero total");
        require(_data.totalSold == 0, "DutchAuction: non-zero total");
        require(_data.totalBid == 0, "DutchAuction: non-zero total");
        if (_data.startTime == 0) {
            _data.startTime = uint96(block.timestamp);
            if (_data.finalTime < 4 weeks) {
                _data.finalTime += uint96(block.timestamp);
            }
        }
        require(_data.startTime >= block.timestamp, "DutchAuction: invalid start time");
        require(_data.finalTime > _data.startTime, "DutchAuction: invalid final time");
        require(_data.finalTime < _data.startTime + 4 weeks, "DutchAuction: too long time range");
        require(_data.tickBid > 0, "DutchAuction: invalid tick bid");
        uint256 ticks = (_data.finalTime - _data.startTime) / _data.tickTime;
        require(ticks > 0, "DutchAuction: zero ticks");
        require(_data.startBid >= _data.finalBid, "DutchAuction: invalid bid range");
        require(
            ticks * _data.tickBid > _data.startBid || _data.startBid - ticks * _data.tickBid <= _data.finalBid,
            "DutchAuction: invalid bid range"
        );
        require(_data.finalBid > 0, "DutchAuction: invalid bids");
        require(_data.fundsReceiver != address(0), "DutchAuction: invalid receiver");
        require(_data.auctioneer != address(0), "DutchAuction: invalid auctioneer");
        require(IERC20(_data.bidToken).totalSupply() > 0, "DutchAuction: invalid bid token");

        uint128 fee = _data.total * feeAmount / 1 ether;
        IERC20(_data.sellToken).transferFrom(msg.sender, address(this), _data.total + fee);
        if (fee > 0) {
            IERC20(_data.sellToken).transfer(feeReceiver, fee);
        }

        uint256 id = auctionCount++;
        auctions[id] = _data;

        emit NewAuction(id, _data.sellToken, _data.bidToken, _data);

        return id;
    }

    function buy(uint256 _id, uint256 _amount, uint128 _maxBid) external {
        AuctionData storage auction = auctions[_id];
        require(auction.status == Status.New, "DutchAuction: not new");
        require(block.timestamp >= auction.startTime, "DutchAuction: not started");
        require(block.timestamp < auction.finalTime, "DutchAuction: already finished");
        uint256 ticks = (block.timestamp - auction.startTime) / auction.tickTime;
        uint256 ticked = ticks * auction.tickBid;
        uint256 bid = auction.finalBid;
        if (ticked < auction.startBid - auction.finalBid) {
            bid = auction.startBid - ticked;
        }
        require(bid <= _maxBid, "DutchAuction: submitted too early");

        if (address(auction.allowList) != address(0)) {
            require(auction.allowList.isAllowed(_id, msg.sender), "DutchAuction: not allowed");
        }

        (uint128 total, uint128 totalSold) = (auction.total, auction.totalSold);
        uint256 sold = _amount * total / bid;
        if (sold > total - totalSold) {
            sold = total - totalSold;
        }
        auction.totalSold = uint128(totalSold + sold);
        uint256 bidAmount = sold * bid / total;
        auction.totalBid += uint128(bidAmount);

        IERC20(auction.bidToken).transferFrom(msg.sender, address(this), bidAmount);
        IERC20(auction.sellToken).transfer(msg.sender, sold);

        emit FilledOrder(_id, msg.sender, bidAmount, sold);
    }

    function cancel(uint256 _id) external {
        AuctionData storage auction = auctions[_id];
        require(msg.sender == auction.auctioneer, "DutchAuction: not authorized");
        require(auction.status == Status.New, "DutchAuction: not new");
        require(block.timestamp < auction.startTime, "DutchAuction: already closed");

        auction.status = Status.Cancelled;
        IERC20(auction.sellToken).transfer(msg.sender, auction.total);

        emit CancelledAuction(_id);
    }

    function claim(uint256 _id) external {
        AuctionData storage auction = auctions[_id];
        require(msg.sender == auction.auctioneer || msg.sender == auction.fundsReceiver, "DutchAuction: not authorized");
        require(auction.status == Status.New, "DutchAuction: not new");
        require(
            auction.totalSold == auction.total || block.timestamp >= auction.finalTime, "DutchAuction: already closed"
        );

        uint256 unsold = auction.total - auction.totalSold;
        if (unsold > 0) {
            auction.status = Status.PartiallyFilled;
            IERC20(auction.sellToken).transfer(auction.fundsReceiver, auction.totalSold);
        } else {
            auction.status = Status.Filled;
        }
        IERC20(auction.bidToken).transfer(auction.fundsReceiver, auction.totalBid);

        emit FinalizedAuction(_id, auction.totalBid, auction.totalSold);
    }
}
