// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
contract CnoteMintPass is  ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("Cnote mint pass", "CNOTE MINT PASS") {
        //_owner = address(0x1Fd793c451653C26c94185bC5d5b43a2E4a2e797);
        _owner = msg.sender;
       // _tokenURLS = "https://gateway.pinata.cloud/ipfs/QmcwBHmr6XU5QcBYL35UsEPnSQBJmzz28erxvMmmmmmy6J";
        _contractURL = "https://gateway.pinata.cloud/ipfs/QmcKGQTYRQNMZA5LYaJtiP7u6dMZfpEERXWdRmYeqpzpxZ";
    }

    uint256 public MAX = 9999;
    uint256 public price = 0.001 ether;
    uint256 public maxMint = 5;
    uint256 public totalSupply;
    uint16  public lastMeta = 0;

    string[] _tokenURLS = [  //set the five metadata here.
        "first",
        "second",
        "third",
        "forth",
        "fifth"
    ];

    mapping(uint256 => string) private _tokenURIs;
    mapping(uint16=>uint) public metaTracker;
    mapping(address=>bool) public whiteListed;


    bool public stopWhiteList;
    bool private dontShowURL;
    string private _contractURL;
    string private hiddenURL = ""; // set the hidden url here
    address private _owner;


    function mintNFT(uint256 amt) public payable returns (uint256){
        require(balanceOf(msg.sender) < maxMint, "You can no longer mint");
        uint256 newid = _tokenIds.current();
        require(amt > 0 && amt <= maxMint, "too much minting");
        uint256 totalID = (newid + amt) - 1;
        require( totalID <= MAX, "max mint cap reached");
        require( msg.value == price * amt, "Under priced");
        if(!stopWhiteList)
            require(whiteListed[msg.sender], "You've not been whitelisted");

        for(uint256 i = 1; i <= amt; i++){
            newid = _tokenIds.current();
            _mint(msg.sender, newid);
            _setTokenURI(newid, _tokenURLS[lastMeta]);
            _tokenIds.increment();
            metaTracker[lastMeta]++;
            if(lastMeta < 4){
                // if(lastMeta == 0 && metaTracker[lastMeta] >= 10)
                     lastMeta++;
                // if(lastMeta == 1 && metaTracker[lastMeta] >= 10){
                //     lastMeta++;
                // }
            }else{
                lastMeta = 0;
            }
        }
        totalSupply = _tokenIds.current();
        payable(_owner).transfer(msg.value);
        return newid;
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

    function updateData(uint256 _MAX, uint256 _price, uint256 _maxMint) public onlyOwner {
        MAX = _MAX; price = _price; maxMint = _maxMint;
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
        if(_type == 1){
            for(uint i = 0; i < _users.length; i++)
                whiteListed[_users[i]] = true;
        }else{
            for(uint i = 0; i < _users.length; i++)
                whiteListed[_users[i]] = false;
        }
    }

}
