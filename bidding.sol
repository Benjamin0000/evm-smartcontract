// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/IERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/utils/ERC721Holder.sol";

contract Bidding is ERC1155Holder, ERC721Holder{
    event BidPlaced(address indexed _from, uint indexed _id, uint _value, uint event_id);
    event NewItem(
        uint item_id,
        uint nft_id,
        string name,
        string description,
        string url,
        address C_address,
        uint8 standard,
        uint startTime,
        uint startPrice
    );
    struct Item{
        string name;
        string description;
        string url;
        uint id; //nft id
        address Address; // contract
        uint8 standard; //erc1155 || 721
        uint startTime;
        uint startPrice;
        bool status; // 0||1
        mapping(address=>uint) bidPoints;
        uint points;
        address winner;
        uint lastPoint;
    }
    //users bid data
    struct UserBidData{
        uint points;
        bool eligible;
        uint time;
        uint bonus;
        uint lodged;
    }
    //bidding parameters
    struct Params{
        uint total; // item tracker.
        uint bonusPoint;
        uint sec;
        uint pointPrice; // cost of bid points
        address cnoteToken;
        address mintPass;
        address admin;
        uint eventID;
    }
    mapping(address=>uint) public points; // users point balance.
    mapping(uint=>Item) public items; //items
    Params public ItemData;

    modifier onlyOwner {
        require(msg.sender == ItemData.admin);
        _;
    }
    constructor(){
        ItemData.cnoteToken = address(0x4240898E9db56FF78B4fFA7006Af0c6Ec59D9Ec5);
        ItemData.mintPass = address(0x4240898E9db56FF78B4fFA7006Af0c6Ec59D9Ec5);
        ItemData.admin = msg.sender;
        ItemData.sec = 15;
        ItemData.pointPrice = 0.001 ether;
        ItemData.bonusPoint = 100;
    }

    function listItem(
        string memory name,
        string memory description,
        string memory url,
        uint _id,
        address _address,
        uint8 standard,
        uint startTime,
        uint startPrice
    ) public onlyOwner {
        items[ItemData.total].name = name;
        items[ItemData.total].description = description;
        items[ItemData.total].url = url;
        items[ItemData.total].id = _id;
        items[ItemData.total].Address = _address;
        items[ItemData.total].standard = standard;
        items[ItemData.total].startTime = block.timestamp + (startTime  * 3600);
        items[ItemData.total].startPrice = startPrice;
        ItemData.total+1;
        emit NewItem(
            ItemData.total - 1, _id, name, description, url, _address, standard, startTime, startPrice
        );
    }

    //before transfer make sure user approves dapp
    function buyPoint(uint _points) public {
        require(IERC721(ItemData.mintPass).balanceOf(msg.sender) > 0, "Get the mint pass");
        uint cost = _points * ItemData.pointPrice;
        IERC20(ItemData.cnoteToken).transferFrom(msg.sender, address(this), cost);
        unchecked{
            points[msg.sender] += _points;
        }
    }

    function placeBid(uint id, uint _points) public {
        Item storage item = items[id];
        require(item.standard > 0, "Item does not exist");
        uint balance = points[msg.sender];
        bool hasPass = canPlaceBid(id).eligible;
        uint bidded = item.bidPoints[msg.sender]; //already alotted point
        bool letGo = bidded < ItemData.bonusPoint && hasPass; //new bidder

        require( !item.status, "Bidding ended");
        require( block.timestamp <= item.startTime, "Bidding already started");

        if( letGo ){
            unchecked{
                balance += ( canPlaceBid(id).bonus - bidded );
            }
        }else{
            require( hasPass, "You are not eligible");
        }

        require( balance >= _points, "Insufficient for bid");

        unchecked{
            uint point2 = _points;

            if( letGo ){
                uint result = (ItemData.bonusPoint - bidded);
                if(result <= point2)
                    point2 -= result;
            }

            if( points[msg.sender] >= point2 )
                points[msg.sender] -= point2; //reducing users point

            item.points += _points;
        }
        if( _points >= item.lastPoint ){
            item.winner = msg.sender;
            item.lastPoint = _points;
        }
        unchecked{
            item.bidPoints[msg.sender] += _points;
        }
        ItemData.eventID += 1;
        emit BidPlaced(msg.sender, id, _points, ItemData.eventID);
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
    }

    function getWinner(uint id) private view returns(address) {
        Item storage item = items[id];
        return item.winner;
    }

    function canPlaceBid(uint _id) public view returns(UserBidData memory){
        bool eligible = false;
        uint balance = IERC721(ItemData.mintPass).balanceOf(msg.sender);
        if(balance > 0) eligible = true;

        return UserBidData({
            points: points[msg.sender],
            eligible: eligible,
            time:items[_id].startTime,
            bonus:ItemData.bonusPoint * balance,
            lodged:items[_id].bidPoints[msg.sender]
        });
    }

    function bidEnded(uint id) public view returns(bool){
        Item storage item = items[id];
        uint endTime = item.startTime + ( ItemData.sec * item.points );
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

    function changeSeconds(uint16 _sec) public onlyOwner {
        ItemData.sec = _sec;
    }

    function changeBonusPoint(uint _point) public onlyOwner {
        ItemData.bonusPoint = _point;
    }

    function changePointPrice(uint _price) public onlyOwner {
        ItemData.pointPrice = _price;
    }

    function changeTokenAddress(address _address) public onlyOwner {
        ItemData.cnoteToken = _address;
    }

    function changeMintPassAddress(address _address) public onlyOwner {
        ItemData.mintPass = _address;
    }

    function moveCnotToken(uint amt) public onlyOwner {
        IERC20(ItemData.cnoteToken).transferFrom(address(this), ItemData.admin, amt);
    }

    function moveERC721(address _address, uint _id) public onlyOwner{
        IERC721(_address).transferFrom(address(this), ItemData.admin, _id);
    }

    function moveERC1155( address _address, uint[] memory _id, uint[] memory _amt) public onlyOwner {
        IERC1155(_address).safeBatchTransferFrom(address(this), ItemData.admin, _id, _amt, "");
    }

    function setBonusPoint(uint _points) public onlyOwner {
        ItemData.bonusPoint = _points;
    }
}
