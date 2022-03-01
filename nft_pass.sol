// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0; 
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
contract CnoteMintPass is  ERC721URIStorage, Ownable { 
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("Cnote mint pass", "CNOTE MINT PASS") {
        _owner = address(0x1Fd793c451653C26c94185bC5d5b43a2E4a2e797);
        _contractURL = "ipfs://QmSkqGidC3PNJkHyvpQuGrBX4bgRLw6LRSWrdMVnseWC8V";
        dontShowURL = true;
        rarity[0] = 750;
        rarity[1] = 5000;
        rarity[2] = 50;
        rarity[3] = 2500;
        rarity[4] = 1450;
        rarity[5] = 250;
    }

    uint256 public MAX = 9999;
    uint256 public price = 0.001 ether;
    uint256 public maxMint = 5;
    uint256 public totalSupply; 
    uint16  public lastMeta = 0;

    mapping(uint256 =>string) private _tokenURIs;
    mapping(uint16=>uint) public metaTracker;
    mapping(uint16=>uint) public rarity;
    mapping(address=>bool) public whiteListed;
 
    bool public stopWhiteList;
    bool public dontShowURL;
    string private _contractURL;
    string private hiddenURL = "ipfs://Qma5L25LTiTx5Ar7QshtyiW93s9TcxYVoGrKTxt9HKJkC6"; // set the hidden url here
    address private _owner;

    string[] _tokenURLS = [  
        "ipfs://QmZAkSusBbWvwTNm4j3Dn97C3yLA9GeS2B9bTmJvgx2R8p/1.json", //black
        "ipfs://QmZAkSusBbWvwTNm4j3Dn97C3yLA9GeS2B9bTmJvgx2R8p/2.json", //blue
        "ipfs://QmZAkSusBbWvwTNm4j3Dn97C3yLA9GeS2B9bTmJvgx2R8p/3.json", //gold
        "ipfs://QmZAkSusBbWvwTNm4j3Dn97C3yLA9GeS2B9bTmJvgx2R8p/4.json", //green
        "ipfs://QmZAkSusBbWvwTNm4j3Dn97C3yLA9GeS2B9bTmJvgx2R8p/5.json",  //pink
        "ipfs://QmZAkSusBbWvwTNm4j3Dn97C3yLA9GeS2B9bTmJvgx2R8p/6.json" //teal
    ];

    struct Params{
        uint max; // item tracker. 
        uint price;
        uint maxMint;   
        uint totalSupply;
        bool isWhiteListing;
        bool whiteListed;
    }
     
    function mintNFT(uint256 amt) public payable returns (uint256){
        uint balance = balanceOf(msg.sender); 
        if(msg.sender != owner()){
            require(amt > 0 && amt <= maxMint, "too much minting");
            require(balance + amt <= maxMint, "too much minting");
        }
        uint256 newid = _tokenIds.current(); 
        uint256 totalID = (newid + amt) - 1;
        require( totalID <= MAX, "max mint cap reached");

        if( msg.sender != owner() ){
            require( msg.value >= price * amt, "Under priced");
        }

        if( !stopWhiteList && msg.sender != owner() )
            require(whiteListed[msg.sender], "You've not been whitelisted");

        for(uint256 i = 1; i <= amt; i++){
            newid = _tokenIds.current();
            _mint(msg.sender, newid);
            _setTokenURI(newid, _tokenURLS[lastMeta]); 
            _tokenIds.increment();
            metaTracker[lastMeta]++;
            lastMeta = getMintable(lastMeta); 
        }
        totalSupply = _tokenIds.current();
        payable(_owner).transfer(msg.value); 
        return newid;
    }

    function getMintable(uint16 _id) internal view returns(uint16){
        uint16 _lastMeta;
        if( _id < 5 ){
            for(uint16 i = 1; i <= 5; i++){
                if( metaTracker[_id + i] < rarity[_id + i] ){
                    _lastMeta = _id + i;
                    break;
                } 
            }
        }else{
            if( metaTracker[0] < rarity[0] ){
                _lastMeta = 0;
            }else{
                for(uint16 i = 1; i <= 5; i++){
                    if( metaTracker[i] < rarity[i] ){
                        _lastMeta = i;
                        break;
                    } 
                }
            }
        }
        return _lastMeta;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if(dontShowURL) return hiddenURL;
        return _tokenURIs[tokenId];
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) override internal virtual {
        _tokenURIs[tokenId] = _tokenURI;
    }

    function owner() public override view returns (address) {
        return _owner;
    }

    function burn(uint256 tokenID) public {
        _burn(tokenID);
        if(totalSupply > 0){
            unchecked {
                totalSupply -= 1;
            }
        }
    }

    function updateData(uint256 _price, uint256 _maxMint) public onlyOwner {
         price = _price; maxMint = _maxMint;
    }

    function updateTokenUrl(string[] memory _url) public onlyOwner {
        for(uint i = 0; i < _url.length; i++){
            _tokenURLS[i] = _url[i];
        }
    }

    function updateContractUrl(string memory _url) public onlyOwner {
        _contractURL = _url;
    }

    function contractURI() public view returns (string memory){
        return _contractURL;
    }

    function setWhiteList(bool status) public onlyOwner {
        stopWhiteList = status;
    }

    function hideURL(bool status) public onlyOwner {
        dontShowURL = status;
    } 

    function addToWhiteList(address[] memory _users, uint8 _type) public onlyOwner {
        for( uint i = 0; i < _users.length; i++ ){
            if(_type == 1){
                whiteListed[_users[i]] = true;
            }else{
                whiteListed[_users[i]] = false;
            }
        }
    }
 
    function getData() public view returns(Params memory){
        return Params({
            max: MAX,
            price: price,  
            maxMint:maxMint, 
            totalSupply:totalSupply,
            isWhiteListing:!stopWhiteList,
            whiteListed:whiteListed[msg.sender]
        });
    }

}