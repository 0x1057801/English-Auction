// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {EnglishAuction} from "../src/EnglishAuction.sol";
import {MockNFT} from "./MockNFT.sol";  // ✅ Use our mock

contract EnglishAuctionTest is Test {
    EnglishAuction public auction;
    MockNFT public nft;  // ✅ Changed from ERC721Mock
    
    address public seller = makeAddr("seller");
    address public bidder1 = makeAddr("bidder1");
    address public bidder2 = makeAddr("bidder2");
    
    uint256 public constant RESERVE_PRICE = 1 ether;
    uint256 public constant DURATION = 7 days;
    uint256 public tokenId;
    
    function setUp() public {
        // Deploy contracts
        auction = new EnglishAuction();
        nft = new MockNFT();  // ✅ Changed
        
        // Mint NFT to seller
        vm.prank(seller);
        tokenId = nft.mint(seller);  // ✅ Our mint returns tokenId
        
        // Give bidders some ETH
        vm.deal(bidder1, 10 ether);
        vm.deal(bidder2, 10 ether);
    }

    // TESTING DEPOSIT CREATES AUCTION
    function testDepositCreatesAuction() public {

        // seller approves auction contract to xfer NFT
        // start by setting msg.sender for all calls until stopPrank
        vm.startPrank(seller);
        nft.approve(address(auction), tokenId);

        // seller calls deposit and deposits their NFT
        // stores reutnred auctionId 
        uint256 auctionId = auction.deposit(
            address(nft),
            tokenId,
            RESERVE_PRICE,
            DURATION
        );
        vm.stopPrank();

        // this took forever... verifying auction created
        (
            address auctionSeller,
            address nftContract,
            , // already declared tokenId above, removing here as its usable and the warning was confusing
            uint256 reservePrice,
            uint256 deadline,
            address highestBidder,
            uint256 highestBid,
            bool ended
        ) = auction.auctions(auctionId);

        assertEq(auctionSeller, seller);
        assertEq(nftContract, address(nft));
        assertEq(reservePrice, RESERVE_PRICE);
        assertEq(deadline, block.timestamp + DURATION);
        assertEq(highestBidder, address(0));
        assertEq(highestBid, 0);
        assertEq(ended, false);

        // now we want to verify NFT xfered to auction contract
        assertEq(nft.ownerOf(tokenId), address(auction));
    }

    // TESTING BID SUCCESS
    function testBidSucceeds() public {
        // seller approves auction contract to xfer NFT
        // start by setting msg.sender for all calls until stopPrank
        vm.startPrank(seller);
        nft.approve(address(auction), tokenId);

        // seller calls deposit and deposits their NFT
        // stores reutnred auctionId 
        uint256 auctionId = auction.deposit(
            address(nft),
            tokenId,
            RESERVE_PRICE,
            DURATION
        );
        vm.stopPrank();

        // Bidder1 bids 2 ether
        vm.prank(bidder1);
        auction.bid{value: 2 ether}(auctionId);

        // Verify highestBidder is bidder1 and verify highestBid is 2 ether
        // Get auction data
        // I learned about the nifty little trick directly below form Patrick Collins!
        // He's so cool! (but I did mess up the # of commas for a while)
        (,,,,,address highestBidder, uint256 highestBid,) = auction.auctions(auctionId);

        assertEq(highestBidder, bidder1);
        assertEq(highestBid, 2 ether);
    }

    // TESTING AUCTION END STATES
    function testEndAuctionReserveMet() public {

        // need to create an auction.... again...
        vm.startPrank(seller);
        nft.approve(address(auction), tokenId);
        uint256 auctionId = auction.deposit(
            address(nft),
            tokenId,
            RESERVE_PRICE,
            DURATION
        );
        vm.stopPrank();

        // bidding above the reserve here
        vm.prank(bidder1);
        auction.bid{value: 2 ether}(auctionId);

        // THIS MESSED ME UP!  I HAVE TO TIME TRAVEL !?!?
        // have to fast forward past the deadline
        vm.warp(block.timestamp + DURATION + 1);

        // go ahead and end the auction
        auction.endAuction(auctionId);

        // verify nft went to the winner
        assertEq(nft.ownerOf(tokenId), bidder1);

        // verify seller got their ETH
        assertEq(seller.balance, 2 ether);

        // make sure the auction state - ended - is set to true
        (,,,,,,,bool ended) = auction.auctions(auctionId);
        assertTrue(ended);
    }

    function testEndAuctionReserveNotMet() public {
        // GUESS WHAT?! ... create an auction... our favorite thing...
        vm.startPrank(seller);
        nft.approve(address(auction), tokenId);
        uint256 auctionId = auction.deposit(
            address(nft),
            tokenId,
            RESERVE_PRICE,
            DURATION
        );
        vm.stopPrank();

        // bid below the reserve price
        vm.prank(bidder1);
        auction.bid{value: 0.5 ether}(auctionId);

        // TRAVEL THROUGH TIIIIIIIME
        vm.warp(block.timestamp + DURATION + 1);

        // go ahead and get bidder1's balance to check against
        uint256 bidder1BalanceBefore = bidder1.balance;

        // we end the auction here
        auction.endAuction(auctionId);

        // verify NFT went back to seller
        assertEq(nft.ownerOf(tokenId), seller);

        // verify bidder got refunded
        assertEq(bidder1.balance, bidder1BalanceBefore + 0.5 ether);

        // verify ended set to true
        (,,,,,,,bool ended) = auction.auctions(auctionId);
        assertTrue(ended);
    }

    function testEndAuctionNoBids() public {

        // you know the drill by now (creating an auction)
        vm.startPrank(seller);
        nft.approve(address(auction), tokenId);
        uint256 auctionId = auction.deposit(
            address(nft),
            tokenId,
            RESERVE_PRICE,
            DURATION
        );
        vm.stopPrank();

        // we aren't going to set up a bid because... we're testing for no bids

        // I'm becoming the regular Dr. Who
        vm.warp(block.timestamp + DURATION + 1);

        // ending auction
        auction.endAuction(auctionId);

        // verify NFT back to seller
        assertEq(nft.ownerOf(tokenId), seller);

        // verify ended == true
        (,,,,,,,bool ended) = auction.auctions(auctionId);
        assertTrue(ended);
    }

    function testCannotEndBeforeDeadline() public {

        // Zzzzzzz....
        vm.startPrank(seller);
        nft.approve(address(auction), tokenId);
        uint256 auctionId = auction.deposit(
            address(nft),
            tokenId,
            RESERVE_PRICE,
            DURATION
        );
        vm.stopPrank();

        // here we try to end auction before the deadline
        vm.expectRevert("Auction still active");
        auction.endAuction(auctionId);
    }

    // this was a weird edge case I thought up to test
    function testCannotEndTwice() public {

        // I refuse to comment this again... wait..
        vm.startPrank(seller);
        nft.approve(address(auction), tokenId);
        uint256 auctionId = auction.deposit(
            address(nft),
            tokenId,
            RESERVE_PRICE,
            DURATION
        );
        vm.stopPrank();

        // bidder goes all in
        vm.prank(bidder1);
        auction.bid{value: 2 ether}(auctionId);

        // flux capacitation
        vm.warp(block.timestamp + DURATION + 1);

        // end ONCE
        auction.endAuction(auctionId);

        // try and end it again
        vm.expectRevert("Auction is ended");
        auction.endAuction(auctionId);
    }

    // BIDDER-X OUTBIDS BIDDER-Y (TESTING CONTRACT INTENTION WORKS AS...INTENDED)
    function testBidderGetsRefundedWhenOutbid() public {

        // make it stop...
        vm.startPrank(seller);
        nft.approve(address(auction), tokenId);
        uint256 auctionId = auction.deposit(
            address(nft),
            tokenId,
            RESERVE_PRICE,
            DURATION
        );
        vm.stopPrank();

        // bidder1 bids 1 ether
        vm.prank(bidder1);
        auction.bid{value: 1 ether}(auctionId);

        // need bidder1's balance to check against
        uint256 bidder1BalanceAfterBid = bidder1.balance;

        // bidder2 ruins bidderr1's hopes and dreams
        vm.prank(bidder2);
        auction.bid{value: 2 ether}(auctionId);

        // verify bidder1 gets their refund
        assertEq(bidder1.balance, bidder1BalanceAfterBid + 1 ether);

        // verify bidder2 is now highestBidder with their bid the highestBid
        (,,,,,address highestBidder, uint256 highestBid,) = auction.auctions(auctionId);
        assertEq(highestBidder, bidder2);
        assertEq(highestBid, 2 ether);
    }
}