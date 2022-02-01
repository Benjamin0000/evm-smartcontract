// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/IERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/utils/ERC721Holder.sol";

contract Bidding is ERC1155Holder, ERC721Holder{

    struct Item{
        string title;
        uint id; //nft id
        address Address; // contract
        uint8 standard; //erc1155 || 721
        uint startTime; 
        uint price;
        uint startPrice;
        bool status; // 0||1 
        mapping(address=>uint) bidPoints;
        address[] bidders;
        uint points;
    }
    
    uint16 public sec;
    uint public pointPrice; // set in ether
    address cnoteTokenAddress;
    address minPass;
    address admin = address(0x1Fd793c451653C26c94185bC5d5b43a2E4a2e797);

    mapping(address=>uint) public points;
    mapping(uint=>Item) public items;

    constructor() {
        sec = 15;
    }

    function listItem() public {

    }
    
    //before transfer make sure user approves dapp
    function buyPoint(uint _points) public {
        require(IERC721(minPass).balanceOf(msg.sender) > 0, "Get the mint pass");
        uint cost = _points * pointPrice;
        IERC20(cnoteTokenAddress).transferFrom(msg.sender, address(this), cost);
        unchecked{
            points[msg.sender] += _points;
        }
    }

    function placeBid(uint id, uint _points) public {
        Item storage item = items[id];
        require( !item.status, "Bidding ended");
        require( block.timestamp <= item.startTime, "Bidding already started");
        require( points[msg.sender] >= _points, "Insuficient for bid");

        unchecked{
            points[msg.sender] -= _points;
            item.points += _points;
        }
        item.bidders.push(msg.sender);
        item.bidPoints[msg.sender] = _points;
    }

    function claimPrice(uint id) public {
        Item storage item = items[id];
        require( item.bidPoints[msg.sender] > 0, "You are not in this contest" ); 
        require( block.timestamp > item.startTime, "Bidding has not started" );
        require( !item.status, "Already claimed");
        require( bidEnded(id), "Bidding has not ended");
        
        if( msg.sender == getWinner(id) ){
            if(item.standard == 1)
                sendERC721(item, msg.sender);
            else
                sendERC1155(item, msg.sender);
        }
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

    function changeSeconds(uint16 _sec) public {
        require(msg.sender == admin, "Unathorized");
        sec = _sec;
    }

    function changePointPrice(uint _price) public {
        require(msg.sender == admin, "Unathorized");
        pointPrice = _price;
    }
    
}