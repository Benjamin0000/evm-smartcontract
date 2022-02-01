// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0; 
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract CnoteMintPass is  ERC721URIStorage{ 
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("Cnot mint pass", "CNOT MINT PASS") {
        owner = address(0x1Fd793c451653C26c94185bC5d5b43a2E4a2e797);
        _tokenURL = "https://gateway.pinata.cloud/ipfs/QmcwBHmr6XU5QcBYL35UsEPnSQBJmzz28erxvMmmmmmy6J";
        _contractURL = "https://gateway.pinata.cloud/ipfs/QmcKGQTYRQNMZA5LYaJtiP7u6dMZfpEERXWdRmYeqpzpxZ";
    }

    uint256 public MAX = 9999;
    uint256 public price = 0.001 ether;
    uint256 public maxMint = 5;
    uint256 public totalSupply;

    string public _tokenURL;
    string private _contractURL;
    address public owner;
   
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function mintNFT(uint256 amt) public payable returns (uint256){
        uint256 newid = _tokenIds.current();
        require(amt > 0 && amt <= maxMint, "too much minting");
        uint256 totalID = (newid + amt) - 1;
        require( totalID <= MAX, "max mint cap reached");
        require( msg.value == price * amt, "Under priced");

        for(uint256 i = 1; i <= amt; i++){
            newid = _tokenIds.current();
            _mint(msg.sender, newid);
            _setTokenURI(newid, _tokenURL);
            _tokenIds.increment();
        }
        totalSupply = _tokenIds.current();
        payable(owner).transfer(msg.value); 
        return newid;
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

    function updateTokenUrl(string memory _url) public onlyOwner {
        _tokenURL = _url;
    }

    function updateContractUrl(string memory _url) public onlyOwner {
        _contractURL = _url;
    }

    function contractURI() public view returns (string memory){
        return _contractURL;
    }

}