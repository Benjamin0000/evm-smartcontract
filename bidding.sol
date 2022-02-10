// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/IERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/utils/ERC721Holder.sol";

contract Bidding is ERC1155Holder, ERC721Holder{

    struct Item{
        string name;
        string description;
        string url;
        uint id; //nft id
        address Address; // contract
        uint8 standard; //erc1155 || 721
        uint startTime;
        uint price; //actual price
        uint startPrice;
        bool status; // 0||1
        mapping(address=>uint) bidPoints;
        address[] bidders;
        uint points;
        address winner;
    }

    // used to get biddings data
    struct UserBidData{
        uint points;
        bool eligible;
        uint time;
        uint bonus;
        uint lodged;
    }

    uint total;

    uint public bonusPoint = 100;
    uint16 public sec = 15;
    uint public pointPrice; // set in ether
    address cnoteToken;
    address mintPass = address(0x4240898E9db56FF78B4fFA7006Af0c6Ec59D9Ec5);
    //address admin = address(0x1Fd793c451653C26c94185bC5d5b43a2E4a2e797);
    address admin = address(0x93EC829Ca2Eb2d49Db55Cb6799189f6f2D3C1DC1);
    mapping(address=>uint) public points;
    mapping(uint=>Item) public items;

    modifier onlyOwner {
        require(msg.sender == admin);
        _;
    }

    function listItem(
        string memory name,
        string memory description,
        string memory url,
        uint _id,
        address _address,
        uint8 standard,
        uint startTime,
        uint price,
        uint startPrice
    ) public onlyOwner {
        items[total].name = name;
        items[total].description = description;
        items[total].url = url;
        items[total].id = _id;
        items[total].Address = _address;
        items[total].standard = standard;
        items[total].startTime = block.timestamp + (startTime  * 3600);
        items[total].startPrice = startPrice;
        items[total].price = price;
        total+1;
    }

    //before transfer make sure user approves dapp
    function buyPoint(uint _points) public {
        require(IERC721(mintPass).balanceOf(msg.sender) > 0, "Get the mint pass");
        uint cost = _points * pointPrice;
        IERC20(cnoteToken).transferFrom(msg.sender, address(this), cost);
        unchecked{
            points[msg.sender] += _points;
        }
    }

    function placeBid(uint id, uint _points) public {
        Item storage item = items[id];
        uint balance = points[msg.sender];
        bool hasPass = canPlaceBid(id).eligible;
        uint bidded = item.bidPoints[msg.sender]; //already alotted point
        bool letGo = bidded < bonusPoint && hasPass; //new bidder

        require( !item.status, "Bidding ended");
        require( block.timestamp <= item.startTime, "Bidding already started");

        if( letGo ){
            unchecked{
                balance += (bonusPoint - bidded);
            }
        }else{
            require( hasPass, "You are not eligible");
        }

        require( balance >= _points, "Insufficient for bid");

        unchecked{
            uint point2 = _points;

            if( letGo ){
                uint result = (bonusPoint - bidded);
                if(result <= point2)
                    point2 -= result;
            }

            if( points[msg.sender] >= point2 )
                points[msg.sender] -= point2; //reducing users point

            item.points += _points;
        }

        item.bidders.push(msg.sender);
        unchecked{
            item.bidPoints[msg.sender] += _points;
        }
    }

    function claimPrice(uint id) public {
        Item storage item = items[id];
        require( item.bidPoints[msg.sender] > 0, "You are not in this contest" );
        require( block.timestamp > item.startTime, "Bidding has not started" );
        require( !item.status, "Already claimed");
        require( bidEnded(id), "Bidding has not ended");
        require( canPlaceBid(id).eligible, "You are not eligible");

        if( msg.sender == getWinner(id) ){
            if(item.standard == 1)
                sendERC721(item, msg.sender);
            else
                sendERC1155(item, msg.sender);
        }

        item.winner = msg.sender;
    }

    function getWinner(uint id) private view returns(address) {
        Item storage item = items[id];
        uint bids = 0;
        address winner = address(0);
        for(uint i = 0; i < item.bidders.length; i++){

            uint _points = item.bidPoints[ item.bidders[i] ];
            if( bids < _points){
                bids = _points;
                winner = item.bidders[i];
            }
        }
        return winner;
    }

    function canPlaceBid(uint _id) public view returns(UserBidData memory){
        bool eligible = false;
        if(IERC721(mintPass).balanceOf(msg.sender) > 0) eligible = true;

        return UserBidData({
            points: points[msg.sender],
            eligible: eligible,
            time:items[_id].startTime,
            bonus:bonusPoint,
            lodged:items[_id].bidPoints[msg.sender]
        });
    }

    function bidEnded(uint id) public view returns(bool){
        Item storage item = items[id];
        uint endTime = item.startTime + ( sec * item.points );
        return block.timestamp >= endTime;
    }

    function sendERC721(Item storage item, address to) private {
        IERC721(item.Address).transferFrom(address(this), to, item.id);
        item.status = true;
    }

    function sendERC1155(Item storage item, address to) private {
        IERC1155(item.Address).safeTransferFrom(address(this), to, item.id, 1, "");
        item.status = true;
    }

    function changeSeconds(uint16 _sec) public onlyOwner{
        sec = _sec;
    }

    function changePointPrice(uint _price) public onlyOwner {
        pointPrice = _price;
    }

    function changeTokenAddress(address _address) public onlyOwner {
        cnoteToken = _address;
    }

    function changeMintPassAddress(address _address) public onlyOwner {
        mintPass = _address;
    }

    function moveCnotToken(uint amt) public onlyOwner {
        IERC20(cnoteToken).transferFrom(address(this), admin, amt);
    }

    function moveERC721(address _address, uint _id) public onlyOwner{
        IERC721(_address).transferFrom(address(this), admin, _id);
    }

    function moveERC1155( address _address, uint[] memory _id, uint[] memory _amt) public onlyOwner {
        IERC1155(_address).safeBatchTransferFrom(address(this), admin, _id, _amt, "");
    }

    function setBonusPoint(uint _points) public onlyOwner{
        bonusPoint = _points;
    }
}
