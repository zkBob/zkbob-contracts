// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IAllowList.sol";
import "../utils/Ownable.sol";

contract EnglishAuction is Ownable {
    enum Status {
        New,
        Cancelled,
        Claimed,
        Filled,
        ClaimedFilled
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
        uint128 currentBid;
        uint128 tickBid;
        uint128 total;
        address currentBidder;
        uint96 lastBidTime;
    }

    uint256 public auctionCount;
    mapping(uint256 => AuctionData) internal auctions;

    uint96 public feeAmount;
    address public feeReceiver;

    event NewAuction(uint256 indexed id, address indexed sellToken, address indexed bidToken, AuctionData data);
    event NewBid(uint256 indexed id, address indexed user, uint256 bidAmount, uint256 bidTime);
    event CancelledAuction(uint256 indexed id);
    event Claimed(uint256 indexed id, address indexed user);
    event FinalizedAuction(uint256 indexed id, uint256 bid);

    constructor(uint96 _fee, address _feeReceiver) Ownable() {
        _setFee(_fee, _feeReceiver);
    }

    function setFee(uint96 _fee, address _feeReceiver) external onlyOwner {
        _setFee(_fee, _feeReceiver);
    }

    function _setFee(uint96 _fee, address _feeReceiver) internal {
        if (_fee > 0) {
            require(_fee <= 0.02 ether, "EnglishAuction: fee too high");
            require(_feeReceiver != address(0), "EnglishAuction: empty fee receiver");
        }
        feeAmount = _fee;
        feeReceiver = _feeReceiver;
    }

    function auctionData(uint256 _id) external view returns (AuctionData memory) {
        return auctions[_id];
    }

    function start(AuctionData memory _data) external returns (uint256) {
        require(_data.status == Status.New, "EnglishAuction: not new");
        require(_data.total > 0, "EnglishAuction: non-zero total");
        if (_data.startTime == 0) {
            _data.startTime = uint96(block.timestamp);
            if (_data.finalTime < 4 weeks) {
                _data.finalTime += uint96(block.timestamp);
            }
        }

        require(_data.startTime >= block.timestamp, "EnglishAuction: invalid start time");
        require(_data.finalTime > _data.startTime, "EnglishAuction: invalid final time");
        require(_data.finalTime < _data.startTime + 4 weeks, "EnglishAuction: too long time range");

        require(_data.tickTime > 0, "EnglishAuction: invalid tick");
        require(_data.tickBid > 0, "EnglishAuction: invalid tick bid");
        require(_data.startBid > 0, "EnglishAuction: invalid start bid");
        require(_data.currentBid == 0, "EnglishAuction: non-zero current bid");
        require(_data.lastBidTime == 0, "EnglishAuction: non-zero last bid time");
        require(_data.fundsReceiver != address(0), "EnglishAuction: invalid receiver");
        require(_data.auctioneer != address(0), "EnglishAuction: invalid auctioneer");
        require(IERC20(_data.bidToken).totalSupply() > 0, "EnglishAuction: invalid bid token");

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

    function bid(uint256 _id, uint256 _bid) external {
        AuctionData storage auction = auctions[_id];
        require(auction.status == Status.New, "EnglishAuction: not new");
        require(block.timestamp >= auction.startTime, "EnglishAuction: not started");
        require(block.timestamp < auction.finalTime, "EnglishAuction: already finished");
        if (address(auction.allowList) != address(0)) {
            require(auction.allowList.isAllowed(_id, msg.sender), "EnglishAuction: not allowed");
        }

        if (auction.currentBidder == address(0)) {
            require(_bid >= auction.startBid, "EnglishAuction: bid too small");
        } else {
            require(_bid >= auction.currentBid + auction.tickBid, "EnglishAuction: bid too small");
            require(block.timestamp < auction.lastBidTime + auction.tickTime, "EnglishAuction: tick passed");
            require(auction.currentBidder != msg.sender, "EnglishAuction: already top bidder");

            IERC20(auction.bidToken).transfer(auction.currentBidder, auction.currentBid);
        }
        IERC20(auction.bidToken).transferFrom(msg.sender, address(this), _bid);
        auction.currentBidder = msg.sender;
        auction.currentBid = uint128(_bid);
        auction.lastBidTime = uint96(block.timestamp);

        emit NewBid(_id, msg.sender, _bid, block.timestamp);
    }

    function cancel(uint256 _id) external {
        AuctionData storage auction = auctions[_id];
        require(msg.sender == auction.auctioneer, "EnglishAuction: not authorized");
        require(auction.status == Status.New, "EnglishAuction: not new");
        require(block.timestamp < auction.startTime, "EnglishAuction: already closed");

        auction.status = Status.Cancelled;
        IERC20(auction.sellToken).transfer(msg.sender, auction.total);

        emit CancelledAuction(_id);
    }

    function claimForWinner(uint256 _id) external {
        AuctionData storage auction = auctions[_id];
        require(auction.status == Status.New || auction.status == Status.Filled, "EnglishAuction: not new or filled");
        require(
            block.timestamp > auction.finalTime || block.timestamp >= auction.lastBidTime + auction.tickTime,
            "EnglishAuction: waiting for tick"
        );
        require(auction.currentBidder != address(0), "EnglishAuction: no bidders");

        auction.status = auction.status == Status.New ? Status.Claimed : Status.ClaimedFilled;
        IERC20(auction.sellToken).transfer(auction.currentBidder, auction.total);

        emit Claimed(_id, auction.currentBidder);
    }

    function claim(uint256 _id) external {
        AuctionData storage auction = auctions[_id];
        require(
            msg.sender == auction.auctioneer || msg.sender == auction.fundsReceiver, "EnglishAuction: not authorized"
        );
        require(auction.status == Status.New || auction.status == Status.Claimed, "EnglishAuction: not new or claimed");
        require(
            block.timestamp > auction.finalTime || block.timestamp >= auction.lastBidTime + auction.tickTime,
            "EnglishAuction: waiting for tick"
        );

        if (auction.currentBidder != address(0)) {
            auction.status = auction.status == Status.New ? Status.Filled : Status.ClaimedFilled;
            IERC20(auction.bidToken).transfer(auction.fundsReceiver, auction.currentBid);

            emit FinalizedAuction(_id, auction.currentBid);
        } else {
            auction.status = Status.Cancelled;
            IERC20(auction.sellToken).transfer(auction.fundsReceiver, auction.total);

            emit CancelledAuction(_id);
        }
    }
}
