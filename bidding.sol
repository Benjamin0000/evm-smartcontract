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
        uint startPrice,
        uint price,
        string imageUrl,
        uint8 _type
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
        address fraction; 
        uint eventID;
    }
    mapping(address=>uint) public points; // users point balance.
    mapping(uint=>Item) public items; //items
    Params public ItemData;

    mapping(uint=>address[]) public winners; // get fraction winners
    mapping(uint=>uint[]) public bidPoints; // used during fraction
    mapping(uint=>uint8) public itemType;
    mapping(uint=>mapping(address=>bool)) public UserClaimedFraction;
    mapping(uint=>uint) public claimedFraction;

    modifier onlyOwner {
        require(msg.sender == ItemData.admin);
        _;
    }
    constructor(){
        ItemData.cnoteToken = address(0x353f624874a9067CDaF0Ce867f9B33a5d98a01e7);
        ItemData.mintPass = address(0xB1930BD2DA20d6FD6FDbA1c18B989C44d30F085C);
        ItemData.admin = 0x1Fd793c451653C26c94185bC5d5b43a2E4a2e797;
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
        uint startPrice,
        uint price,
        string memory imageUrl,
        uint8 _type 
    ) public onlyOwner {
        itemType[ItemData.total] = _type;
        items[ItemData.total].name = name;
        items[ItemData.total].description = description;
        items[ItemData.total].url = url;
        items[ItemData.total].id = _id;
        items[ItemData.total].Address = _address;
        items[ItemData.total].standard = standard;
        items[ItemData.total].startTime = block.timestamp + (startTime  * 60);  
        items[ItemData.total].startPrice = startPrice;
        ItemData.total+=1;
        emit NewItem(
            ItemData.total - 1, _id, name, description, url, _address, standard, startTime, startPrice, price, imageUrl, _type
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
        uint bonus = canPlaceBid(id).bonus;
        bool letGo = bidded < bonus; //new bidder
        uint8 _type = itemType[id]; 

        require( !item.status, "Bidding ended");
        require( block.timestamp <= item.startTime, "Bidding already started");

        if( letGo ){
            unchecked{
                balance += ( bonus - bidded );
            }
        }else{
            require( hasPass, "You are not eligible");
        }

        require( balance >= _points, "Insufficient for bid");

        unchecked{
            uint point2 = _points;

            if( letGo ){
                uint result = (bonus - bidded);
                if(result <= point2)
                    point2 -= result;
            }

            if( points[msg.sender] >= point2 )
                points[msg.sender] -= point2; //reducing users point

            item.points += _points;
        }
        unchecked{
            item.bidPoints[msg.sender] += _points;
        }
        uint bid = item.bidPoints[msg.sender];

        if(_type == 0){
            if( bid > item.lastPoint ){
                item.winner = msg.sender;
                item.lastPoint = bid;
            }
        }else{
            (bool exists, uint index) = userExists(id, msg.sender);
            if( winners[id].length < _type ){
                if(!exists){
                    bidPoints[id][ winners[id].length ] = bid;
                    winners[id][ winners[id].length ] = msg.sender;
                }else{
                    bidPoints[id][ index ] = bid;
                }
            }else{
                for( uint8 i = 0; i < _type; i++ ){
                    if( bid > bidPoints[id][i] && !exists ){
                        bidPoints[id][i] = bid;
                        winners[id][i] = msg.sender;
                        break;
                    }else if( bid > bidPoints[id][i] && exists ){
                        bidPoints[id][index] = bid; 
                        break;
                    }
                }
            }
        }
        ItemData.eventID += 1;
        emit BidPlaced(msg.sender, id, _points, ItemData.eventID);
    }

    function userExists(uint _id, address _address) internal view returns (bool, uint){
        for( uint i = 0; i < winners[_id].length; i++ ){
            if(winners[_id][i] == _address)
                return (true, i);
        }
        return (false, 0);
    }

    function claimPrice(uint id) public {
        Item storage item = items[id];
        uint8 _type = itemType[id]; 

        require( item.bidPoints[msg.sender] > 0, "You are not in this contest" );
        require( block.timestamp > item.startTime, "Bidding has not started" );
        require( !item.status, "Already claimed");
        require( bidEnded(id), "Bidding has not ended");
        require( canPlaceBid(id).eligible, "You are not eligible");

        if( _type == 0 ){
            if( msg.sender == item.winner ){
                if(item.standard == 1)
                    sendERC721(item, msg.sender);
                else
                    sendERC1155(item, msg.sender);
            }
        }else{
            require( claimedFraction[id] < _type, "Everything claimed");
            require( !UserClaimedFraction[id][msg.sender], "Already claimed" );
            setFraction();
            UserClaimedFraction[id][msg.sender] = true;
            claimedFraction[id]++;
            if( claimedFraction[id] >= _type ){
                if(item.standard == 1)
                    sendERC721(item, ItemData.fraction);
                else
                    sendERC1155(item, ItemData.fraction);
            } 
        }
    }

    function setFraction() public {

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

    function changeFractionAddress(address _address) public onlyOwner{
        ItemData.fraction = _address;
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
