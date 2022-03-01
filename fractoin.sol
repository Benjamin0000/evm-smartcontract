// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0; 
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/IERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/utils/ERC721Holder.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

contract Fraction is ERC1155Holder, ERC721Holder{
    address bidding_address;
    address admin_address;
    address note_token_address;

    modifier onlyOwner {
        require(msg.sender == admin_address);
        _;
    }

    //Describe the fractioned item. 
    struct ItemStruct{    
        uint price;
        address[] Owners;
        bool status; //determin if still valid
        uint8 qty;   //no. of rqd owners
    }

    //describe the item owned by user
    struct ItemUserStruct{
        bool exists; 
        uint price;
        bool selling;
        address offerer;
        uint lastOffer; 
    }

    mapping(uint=>ItemStruct) public Items;

    mapping(address=>uint[]) public Owned; //tracking what users own

    mapping( address=>mapping(uint=>ItemUserStruct) ) public ItemUserData; // tracking state of users item


    constructor(){
        admin_address = msg.sender;
    }

    //make an offer to owner or seller
    /**
     * Make a buy offer
     * - `_id` item no.
     */ 
    function makeOffer(uint _id, uint _price,  address _owner) public { 
        require( ItemUserData[_owner][_id].exists, "User not rightful owner" );
        if( _price > ItemUserData[_owner][_id].lastOffer ){

            if( ItemUserData[_owner][_id].lastOffer > 0 ){
                uint lastAmt = ItemUserData[_owner][_id].lastOffer;
                address lastUser = ItemUserData[_owner][_id].offerer;
                IERC20(note_token_address).transfer(lastUser, lastAmt); // returning funds to last offerer
            }
            ItemUserData[_owner][_id].offerer = msg.sender;
            ItemUserData[_owner][_id].lastOffer = _price;
            IERC20(note_token_address).transferFrom(msg.sender, address(this), _price);
        } 
    }

    //accept offer then item gets sent to offerer
    //sender the owner of item
    function acceptOffer(uint _id) public {
        require( ItemUserData[msg.sender][_id].exists, "You are not the rightful owner" );
        address offerer = ItemUserData[msg.sender][_id].offerer;
        uint amt = ItemUserData[msg.sender][_id].lastOffer; 
        require(amt > 0, "invalid offer");
        //send funds to acceptor
        IERC20(note_token_address).transfer(msg.sender, amt);
        //move offerer to owners list. 
        transferOwnership(_id, msg.sender,  offerer);
    }

    /**
     * List item for sale
     * - `_id` item no.
     */ 
    function sell(uint _id, uint _price) public {
        require( ItemUserData[msg.sender][_id].exists, "You are not the rightful owner" );
        ItemUserData[msg.sender][_id].price = _price;
        ItemUserData[msg.sender][_id].selling = true;
    }

    function removeFromSell(uint _id) public {
        require( ItemUserData[msg.sender][_id].exists, "You are not the rightful owner" );
        require( ItemUserData[msg.sender][_id].selling, "Item not selling");
        ItemUserData[msg.sender][_id].selling = false;
    }
    /**
     * purchase what is listed 
     * - `_id` item no.
     *- `_seller` user
     *- user must approve dapp before they can buy
     */ 
    function buy(uint _id, address _seller) public {
        require( ItemUserData[_seller][_id].exists, "Seller not the rightful owner" );
        require( ItemUserData[_seller][_id].selling, "owner not selling");
        uint _price = ItemUserData[_seller][_id].price;
        IERC20(note_token_address).transferFrom(msg.sender, _seller, _price);
        transferOwnership(_id, _seller, msg.sender);
    }

    function transferOwnership(uint _id, address owner, address new_owner) private{
        for( uint i = 0; i < Items[_id].Owners.length; i++ ){
            if( Items[_id].Owners[i] == owner ){
                Items[_id].Owners[i] = new_owner; // replacing old owner
                Owned[new_owner].push(_id); //new owner
                ItemUserData[new_owner][_id].exists = true;

                Owned[owner] = removeItemFromArr(Owned[owner], _id); //denouncing ownership
                ItemUserData[owner][_id].exists = false;
                break;
            }
        }
    }

    function setFraction(uint _id, uint8 _qty, uint _price, address _user) public {
        require( msg.sender == bidding_address, "Unathorized" );

        if( Items[_id].qty != 0 ){
            require( Items[_id].Owners.length < Items[_id].qty );
        }
        Items[_id].price = _price; 

        if(Items[_id].qty == 0)
            Items[_id].qty = _qty;

        //set all the owners 
        Items[_id].Owners.push(_user);
        //set users item as owner
        Owned[_user].push(_id);
        ItemUserData[_user][_id].exists = true;
    } 

    function removeItemFromArr(uint[] memory arr, uint old_val) public pure returns(uint[] memory) {
        uint[] memory newArr;
        uint counter = 0;
        for(uint i = 0; i < arr.length; i++){
            if( arr[i] != old_val ){
                newArr[counter] = arr[i];
                counter++;
            }
        }
        return newArr;
    }

    function setBiddingAddress(address _address) public onlyOwner {
        bidding_address = _address;
    }

}