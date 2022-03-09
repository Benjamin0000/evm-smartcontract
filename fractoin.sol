// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0; 
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import './bidding.sol';

contract Fraction {
    address bidding_address;
    address admin_address;
    address note_token;
    address fee_address;
    address core;
    uint8 constant SET = 1;
    uint8 constant REJECTED = 2;
    uint8 constant OVER_THROWN = 3;
    uint8 constant GRANTED = 4;
    uint8 constant CANCELED = 5;
    uint public fee = 5;
    //Describe the fractioned item.
    struct ItemStruct{    
        uint _id;
        uint price;
        uint count;
        address[] Owners;
        bool exists; //determin if still valid
        uint8 qty;   //no. of rqd owners
        uint8 standard; //erc1155 || 721
    }
    //Describe users fraction.
    struct ItemUserStruct{
        bool exists;
        uint price; 
        bool selling;
        address offerer;
        uint lastOffer; 
    }
    //Describe the state of offers.
    struct OffersStateStruct{
        uint expiry_time;
        uint price;
        uint8 status;
    }

    mapping( uint=>ItemStruct ) public Items;
    mapping( address=>uint[] ) public Owned; //tracking what users own
    mapping( address=>mapping(uint=>uint[]) )  public UsersItem;
    mapping( address=>mapping(uint=>mapping(uint=>ItemUserStruct)) ) public UsersItemInfo; //info for sub items

    mapping( address=>mapping(uint=>uint[]) ) public offersBox;
    mapping( address=>mapping(uint=>mapping(uint=>OffersStateStruct))) public offerInfo;
    mapping( address=>uint[]) public offers; //offers submitted

    modifier senderMustBeOwner(uint _id, uint subID) { 
        require(Items[_id].exists, 'Invalid item');
        require( UsersItemInfo[msg.sender][_id][subID].exists, "You are not the rightful owner" );
        _;
    }

    constructor(){
        core = msg.sender;
        note_token = 0x353f624874a9067CDaF0Ce867f9B33a5d98a01e7; 
        fee_address = 0xBC8143379FA2EB5111DcEE2Fbb139FE436BdD614;
    } 

    //make an offer to owner or seller
    /**
     * Make a buy offer
     * - `_id` item no.
     *- `expiry_time` in seconds
     *- `_price` price offer
     *- `_owner` item owner
     *- status 1 = set, 2 = rejected, 3 = overthrown 4=accepted
     */ 
    function makeOffer(
        uint _id, 
        uint subID,  
        uint _price, 
        address _owner, 
        uint expiry_time
    ) public returns(bool) { 
        require(Items[_id].exists, 'Invalid item');
        uint[] memory items =  UsersItem[_owner][_id];
        require( intExists(items, subID), 'User not the rightfull owner' );
        ItemUserStruct storage item = UsersItemInfo[_owner][_id][subID];
        require(item.exists, "not owner");
        if( _price > item.lastOffer ){ 
            if( item.lastOffer > 0 ){ //refund last offer
                if( offerInfo[item.offerer][_id][subID].status == SET ){
                    IERC20(note_token).transfer(item.offerer, item.lastOffer);
                    offerInfo[item.offerer][_id][subID].status = OVER_THROWN;
                    removeFromOfferList(item.offerer, _id, subID);
                }
            }
            IERC20(note_token).transferFrom(msg.sender, address(this), _price);
            item.offerer = msg.sender;
            item.lastOffer = _price;
            if( !intExists(offersBox[msg.sender][_id],  subID) ) 
                offersBox[msg.sender][_id].push(subID);
            
            if( !intExists(offers[msg.sender], _id) )
                offers[msg.sender].push(_id);

            offerInfo[msg.sender][_id][subID].status = SET;
            offerInfo[msg.sender][_id][subID].expiry_time = block.timestamp + expiry_time;
            offerInfo[msg.sender][_id][subID].price = _price;
            return true;
        }
        return false;
    }

    function rejectOffer(uint _id, uint subID) public senderMustBeOwner(_id, subID) returns (bool) 
    {
        address offerer = UsersItemInfo[msg.sender][_id][subID].offerer;
        require( offerInfo[offerer][_id][subID].status == SET, "Invalid offer");
        uint amt = UsersItemInfo[msg.sender][_id][subID].lastOffer; 
        IERC20(note_token).transfer(offerer, amt); //refund the offerer
        offerInfo[offerer][_id][subID].status = REJECTED;

        UsersItemInfo[msg.sender][_id][subID].offerer = address(0);
        UsersItemInfo[msg.sender][_id][subID].lastOffer = 0;
        removeFromOfferList(offerer, _id, subID);
        return true;
    }

    function removeFromOfferList(address offerer, uint _id, uint subID) private {
        offersBox[offerer][_id] = removeIntFromArr(offersBox[offerer][_id], subID);
        if( offersBox[offerer][_id].length == 0 )
            offers[offerer] = removeIntFromArr(offers[offerer], _id);  //Remove from main list
    }

    function acceptOffer(uint _id, uint subID) public senderMustBeOwner(_id, subID) returns (bool)
    {
        address offerer = UsersItemInfo[msg.sender][_id][subID].offerer;
        require( block.timestamp <= offerInfo[offerer][_id][subID].expiry_time, 'Offer expired');
        require( offerInfo[offerer][_id][subID].status == SET, "Invalid offer");

        uint amt = UsersItemInfo[msg.sender][_id][subID].lastOffer; 
        uint _fee = (amt / 100) * fee;
        
        IERC20(note_token).transfer(msg.sender, amt - _fee); 
        IERC20(note_token).transfer(fee_address, _fee);

        transferOwnership(_id, subID, msg.sender,  offerer, amt); //transfer ownership to offerer
        offerInfo[offerer][_id][subID].status = GRANTED;
        removeFromOfferList(offerer, _id, subID);
        return true;
    }

    function retrieveOffer(uint _id, uint subID, address _owner) public {
        require(Items[_id].exists, 'Invalid item');
        require( offerInfo[msg.sender][_id][subID].status == SET, 'cannot retrieve' );
        ItemUserStruct storage item = UsersItemInfo[_owner][_id][subID];
        require( item.offerer == msg.sender, "unauthorized" );

        IERC20(note_token).transfer(msg.sender, item.lastOffer); 
        removeFromOfferList(msg.sender, _id, subID);
        offerInfo[msg.sender][_id][subID].status = CANCELED;
        UsersItemInfo[_owner][_id][subID].offerer = address(0);
        UsersItemInfo[_owner][_id][subID].lastOffer = 0;
    }

    function buy(uint _id, uint subID, address _owner) public {
        require(Items[_id].exists, 'Invalid item');
        ItemUserStruct storage item = UsersItemInfo[_owner][_id][subID];
        require( item.exists, "User not valid owner");
        require( item.selling, "Owner not selling");
        
        if( item.lastOffer > 0 ){ //refund last offer
            if( offerInfo[item.offerer][_id][subID].status == SET ){
                IERC20(note_token).transfer(item.offerer, item.lastOffer);
                offerInfo[item.offerer][_id][subID].status = OVER_THROWN;
                removeFromOfferList(item.offerer, _id, subID);
            }
        }
        uint _fee = (item.price / 100) * fee;

        IERC20(note_token).transferFrom(msg.sender, _owner, item.price - _fee); 
        IERC20(note_token).transferFrom(msg.sender, fee_address, _fee);
        
        transferOwnership(_id, subID, _owner, msg.sender, item.price);
    }

    function sell(uint _id, uint subID, uint _price) public senderMustBeOwner(_id, subID) {
        UsersItemInfo[msg.sender][_id][subID].selling = true;
        UsersItemInfo[msg.sender][_id][subID].price = _price;
    }

    function removeIntFromArr(uint[] memory arr, uint val) private pure returns(uint[] memory) 
    {
        uint[] memory newArr;
        uint counter = 0;
        for(uint i = 0; i < arr.length; i++){
            if( arr[i] != val ){
                newArr[counter] = arr[i];
                counter++;
            }
        }
        return newArr;
    }

    function removeAddressFromArr(address[] memory arr, address val) private pure returns(address[] memory)
    {
        address[] memory newArr;
        uint counter = 0;
        for(uint i = 0; i < arr.length; i++){
            if( arr[i] != val ){
                newArr[counter] = arr[i];
                counter++;
            }
        }
        return newArr;
    }

    function addressExists(address[] memory arr, address val) private pure returns(bool)
    { 
        for(uint i = 0; i < arr.length; i++){
            if(arr[i] == val)
                return true;
        }
        return false;
    }


    function intExists(uint[] memory arr, uint val) private pure returns(bool) 
    {
        for(uint i = 0; i < arr.length; i++){
            if(arr[i] == val)
                return true;
        }
        return false;
    }

    function setFraction(
        uint _id, 
        uint nftID, 
        uint8 _qty, 
        uint _price,
        address _user) public 
    {
        require( msg.sender == bidding_address, "Unathorized" );
        if( Items[_id].qty != 0 )
            require( Items[_id].Owners.length < Items[_id].qty );
        
        Items[_id].price = _price;

        if(Items[_id].qty == 0)
            Items[_id].qty = _qty;

        //set all the owners 
        Items[_id].Owners.push(_user);
        //set users item as owner
        Owned[_user].push(_id);

        Items[_id].count+=1; //creating fraction ID
        Items[_id].exists = true;
        Items[_id]._id = nftID;
        UsersItem[_user][_id].push( Items[_id].count );
        UsersItemInfo[_user][_id][Items[_id].count].price = _price / Items[_id].qty;
        UsersItemInfo[_user][_id][Items[_id].count].exists = true;
    }
    
    function transferOwnership(
        uint _id, 
        uint subID, 
        address owner, 
        address new_owner,
        uint _price) private {
        UsersItem[owner][_id] = removeIntFromArr(UsersItem[owner][_id], subID);  //removing sub items for owner
        UsersItem[new_owner][_id].push(subID); //add to new users list

        if( UsersItem[owner][_id].length == 0 ){
            Owned[owner] = removeIntFromArr(Owned[owner], _id);  //removing as items owned. 
            Items[_id].Owners = removeAddressFromArr(Items[_id].Owners, owner);
        }
        //new owner 
        if( !intExists(Owned[new_owner], _id) )
            Owned[new_owner].push(_id); 

        if( !addressExists(Items[_id].Owners, new_owner) )
            Items[_id].Owners.push(new_owner);

        UsersItemInfo[owner][_id][subID].exists = false; //previous owner
        UsersItemInfo[new_owner][_id][subID].selling = false;
        UsersItemInfo[new_owner][_id][subID].offerer = address(0);
        UsersItemInfo[new_owner][_id][subID].lastOffer = 0;
        UsersItemInfo[new_owner][_id][subID].price = _price;
        UsersItemInfo[new_owner][_id][subID].exists = true; //new owner 
    }

    function setFee(uint _fee) public {
        require(msg.sender == admin_address, "unathorized");
        fee = _fee;
    }

    function setAddreses(
        address _bidding,
        address _admin, 
        address _note_token, 
        address _fee_address) public {
        require(msg.sender == core, "unauthorized");
        bidding_address = _bidding;
        admin_address = _admin;
        note_token = _note_token;
        fee_address = _fee_address;
    }

    function claimFullNFT(uint _id) public {
        ItemStruct storage item =  Items[_id];
        require( item.exists, "Invalid NFT" );
        require( UsersItem[msg.sender][_id].length == item.qty, "You are not the complete owner" );
        UsersItem[msg.sender][_id] =  new uint[](0);
        Owned[msg.sender] = removeIntFromArr(Owned[msg.sender], _id);
        Bidding(bidding_address).claimAllNFT(_id, item.qty, msg.sender); 
        item.exists = false;
    }

    function getOwned(address _owner) public view returns(uint[] memory){
        return Owned[_owner]; 
    }

    function getTotalOwned(address _owner) public view returns(uint){
        return Owned[_owner].length;
    }

    function getTotalSubOwned(address _owner, uint _id) public view returns(uint){
        return UsersItem[_owner][_id].length;
    }

    function getItems(address _owner, uint _id) public view returns(uint[] memory) {
        return UsersItem[_owner][_id]; 
    }

    //offers
    function totalOffers(address _owner) public view returns(uint){
        return offers[_owner].length;
    }

    function totalSubOffers(address _owner, uint _id) public view returns(uint){
        return offersBox[_owner][_id].length;
    }
}