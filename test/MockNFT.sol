pragma solidity 0.8.33;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract MockNFT is ERC721 {

    // setting up a counter to issue IDs upon minting
    uint256 private _tokenIdCounter;
    
    constructor() ERC721("MockNFT", "MNFT") {}
    
    function mint(address to) public returns (uint256) {

        // assign an ID to tokenId and increment our counter
        uint256 tokenId = _tokenIdCounter++;

        // mint a token to caller
        _mint(to, tokenId);

        // let the caller know their token's ID
        return tokenId;
    }
}