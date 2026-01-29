// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

// need to import a few things to deploy this bad boy
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {EnglishAuction} from "../src/EnglishAuction.sol";
import {MockNFT} from "../test/MockNFT.sol";

contract DeployEnglishAuction is Script {
    
    function run() external {

        // this is just an account from Anvil
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        // begin broadcasting deployment (is that the lingo here?)
        vm.startBroadcast(deployerPrivateKey);

        // now we deploy the two contracts
        EnglishAuction auction = new EnglishAuction();
        MockNFT nft = new MockNFT();

        // mint an NFT to deployer
        uint256 tokenId = nft.mint(vm.addr(deployerPrivateKey));

        // stop broadcasting our deployment transaction
        vm.stopBroadcast();

        // log addressses here just to make sure everything went well
        console.log("English Auction deployed at:", address(auction));
        console.log("MockNFT deployed at:", address(nft));
        console.log("NFT minted - Token ID:", tokenId);
    }
}