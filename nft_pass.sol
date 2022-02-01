// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0; 
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
contract CnoteMintPass is  ERC721URIStorage{ 
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("Cnot mint pass", "CNOT MINT PASS") {}

    uint public MAX = 9999;
    uint public price;
    uint public maxMint = 5;
    string private tokenURL = "https://gateway.pinata.cloud/ipfs/QmcwBHmr6XU5QcBYL35UsEPnSQBJmzz28erxvMmmmmmy6J";
    address admin = address(0x1Fd793c451653C26c94185bC5d5b43a2E4a2e797);

    function mintNFT(uint8 amt) public payable returns (uint256){
        uint256 newid = _tokenIds.current();
        require(amt > 0 && amt <= maxMint, "too much minting");
        require( newid <= MAX && (newid + amt) <= MAX, "max mint cap reached");
        require(msg.value == price * amt, "Under priced");

        for(uint8 i = 1; i <= amt; i++){
             newid = _tokenIds.current();
            _mint(msg.sender, newid);
            _setTokenURI(newid, tokenURL);
            _tokenIds.increment();
        }
        return newid;
    }

    function burn(uint256 tokenID) public {
        _burn(tokenID);
    }

    function updateData(uint _MAX, uint _price, uint _maxMint) public {
        require(msg.sender == admin, "Unauthorized");
        MAX = _MAX; price = _price; maxMint = _maxMint;
    }

    // function _baseURI() internal pure override returns (string memory) {
    //     return "";
    // } 

    function contractURI() public pure returns (string memory){
        //meta data for the contract
        return "https://gateway.pinata.cloud/ipfs/QmcKGQTYRQNMZA5LYaJtiP7u6dMZfpEERXWdRmYeqpzpxZ";
    }

}