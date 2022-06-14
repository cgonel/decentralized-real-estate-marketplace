// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.14;

/**
    @title Real Estate Token Marketplace
*/

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Marketplace {
    // IERC1155 token = IERC1155(0x8ad3aA5d5ff084307d28C8f514D7a193B2Bfe725);
    // IERC20 dai = IERC20(0xc3dbf84Abb494ce5199D5d4D815b10EC29529ff8);
    IERC1155 token;
    IERC20 dai;


    constructor(address _token, address _dai) {
        token = IERC1155(_token);
        dai = IERC20(_dai);
    }

    enum OfferStatus {
        Active,
        Cancelled
    }

    struct Offer {
        uint256 price;
        address offerer;
        OfferStatus status;
    }

    enum ListingStatus {
        Active,
        Sold,
        Cancelled
    }

    struct Listing {
        uint256 tokenId;
        uint256 amount;
        uint256 price;
        address seller;
        ListingStatus status;
        uint256 numOffers;
    }

    uint256 public numListings;
    mapping(uint256 => Listing) public allListings;
    mapping(uint256 => mapping(uint256 => Offer)) public listingToOffers;
    mapping(address => bool) public approvedMarketplaceToken;
    mapping(address => bool) public approvedMarketplaceDAI;

    modifier onlyListingOwner(uint256 _listingId) {
        Listing memory listing = allListings[_listingId];
        require(listing.seller == msg.sender, "Only seller can modify listing");
        _;
    }

    modifier onlyActiveListing(uint256 _listingId) {
        Listing memory listing = allListings[_listingId];
        require(listing.tokenId != 0 && listing.status == ListingStatus.Active, "Listing is not active");
        _;
    }

    /// @notice Allows the marketplace to transfer a token for the user
    function approveMarketplaceToken() external {
        require(token.isApprovedForAll(msg.sender, address(this)), "Has not approved the marketplace to ERC1155 contract");
        approvedMarketplaceToken[msg.sender] = true;
    }

    /// @notice Records the listing created
    /// @param tokenId the id of the real estate token
    /// @param seller the address of the token seller
    /// @param amount the amount of token being listed
    /// @param price the price of the tokens listed
    event SaleCreated(uint256 indexed tokenId, address indexed seller, uint256 amount, uint256 price);

    /// @notice creates a listing
    /// @param _tokenId the token id of the real estate token
    /// @param _amount the amount of token being listed
    /// @param _price the price of the tokens
    function createSale(uint256 _tokenId, uint256 _amount, uint256 _price) external {
        require(approvedMarketplaceToken[msg.sender], "Account hasn't approved the marketplace");
        require(token.balanceOf(msg.sender, _tokenId) >= _amount, "Insufficient tokens");

        Listing memory listing;
        listing.tokenId = _tokenId;
        listing.amount = _amount;
        listing.price = _price;
        listing.seller = msg.sender;

        numListings++;
        allListings[numListings] = listing;

        emit SaleCreated(_tokenId, msg.sender, _amount, _price);
    }

    /// @notice records the updated listing information
    /// @param listingId the id of the listing the user updated
    /// @param seller the seller of the listing
    /// @param amount updated amount
    /// @param price updated price
    event UpdatedSale(uint256 indexed listingId, address indexed seller, uint256 amount, uint256 price);

    /// @notice updates a listing by its owner
    /// @param _listingId  the id of the listing the user wants to update
    /// @param _amount amount they want to sell
    /// @param _price the price they want to sell for
    function updateSale(uint256 _listingId, uint256 _amount, uint256 _price) external onlyListingOwner(_listingId) onlyActiveListing(_listingId) {
        Listing storage listing = allListings[_listingId];
        require(token.balanceOf(msg.sender, listing.tokenId) >= _amount, "Insufficient tokens");
        
        listing.amount = _amount;
        listing.price = _price;

        emit UpdatedSale(_listingId, msg.sender, _amount, _price);
    } 

    /// @notice cancel the listing
    /// @param _listingId the id of the listing
    function cancelSale(uint256 _listingId) external onlyListingOwner(_listingId) onlyActiveListing(_listingId) {
        Listing storage listing = allListings[_listingId];
        listing.status = ListingStatus.Cancelled;
    }

    /// @notice records the token purchased
    /// @param listingId the id of the listing
    /// @param buyer the buyer of the tokens
    /// @param seller the seller of the tokens
    /// @param price the price of the sale
    event TokenPurchased(uint256 indexed listingId, address indexed buyer, address indexed seller, uint256 amount, uint256 price);

    /// @notice buy the tokens
    /// @param _listingId the id of the listing
    function buyToken(uint256 _listingId) external onlyActiveListing(_listingId) payable {
        Listing storage listing = allListings[_listingId];
        require(msg.value == listing.price, "Incorrect funds");
        listing.status = ListingStatus.Sold;
        (bool success, ) = listing.seller.call{value: msg.value}("");
        require(success, "Failed transaction");

        token.safeTransferFrom(listing.seller, msg.sender, listing.tokenId, listing.amount, "0x0");

        emit TokenPurchased(_listingId, msg.sender, listing.seller, listing.amount, listing.price);
    }

    /// @notice approve the marketplace to spend their dai when offer is accepted
    function approveMarketplaceDAI() external {
        require(dai.allowance(msg.sender, address(this)) != 0, "Hasn't approved marketplace to ERC20 contract");
        approvedMarketplaceDAI[msg.sender] = true;
    }

    /// @notice records the creation of an offer
    /// @param listingId the id of the listing
    /// @param offerId the id of the offer
    /// @param offerer the address of the offerer
    /// @param price the price of the offer
    event OfferCreated(uint256 indexed listingId, uint256 indexed offerId, address indexed offerer, uint256 price);

    /// @notice create an offer for a listing
    /// @param _listingId the id of the listing to offer
    /// @param _price the price of the offer
    function createOffer(uint256 _listingId, uint256 _price) external onlyActiveListing(_listingId) {
        require(approvedMarketplaceDAI[msg.sender], "Has not approved marketplace to their DAI");
        require(dai.balanceOf(msg.sender) >= _price, "Offerer has insufficient funds");

        Listing storage listing = allListings[_listingId];
        Offer memory offer;
        offer.offerer = msg.sender;
        offer.price = _price;
        listing.numOffers++;
        listingToOffers[_listingId][listing.numOffers] = offer;

        emit OfferCreated(_listingId, listing.numOffers, msg.sender, _price); 
    }

    /// @notice accept an offer on their listing
    /// @param _listingId the id of the listing
    /// @param _offerId the id of the offer
    function acceptOffer(uint256 _listingId, uint256 _offerId) external {
        Listing storage listing = allListings[_listingId];
        Offer memory offer = listingToOffers[_listingId][_offerId];
        require(msg.sender == listing.seller, "Not seller");
        require(offer.status == OfferStatus.Active, "Offer is inactive");
        listing.status = ListingStatus.Sold;
        bool success = dai.transferFrom(offer.offerer, listing.seller, offer.price);
        require(success, "Failed transaction");

        token.safeTransferFrom(listing.seller, msg.sender, listing.tokenId, listing.amount, "0x0");

        emit TokenPurchased(_listingId, offer.offerer, listing.seller, listing.amount, offer.price);
    }

    /// @notice cancel an offer
    /// @param _listingId the id of the listing
    /// @param _offerId the id of the offer
    function cancelOffer(uint256 _listingId, uint256 _offerId) external {
        Offer storage offer = listingToOffers[_listingId][_offerId];
        require(offer.offerer == msg.sender, "Not the offerer of this offer");
        require(offer.status != OfferStatus.Cancelled, "Offer is inactive");

        offer.status = OfferStatus.Cancelled;
    }

    /// @notice records updated offers
    /// @param listingId the id of the listing
    /// @param offerer the offerer of the offer
    /// @param price the updated price
    event OfferUpdated(uint256 indexed listingId, address indexed offerer, uint256 price);

    /// @notice update an offer
    /// @param _listingId the id of the listing
    /// @param _offerId the id of the offer
    /// @param _price the price to update the offer with
    function updateOffer(uint256 _listingId, uint256 _offerId, uint256 _price) external {
        Offer storage offer = listingToOffers[_listingId][_offerId];
        require(offer.offerer == msg.sender ,"Not the offerer of this offer");
        require(offer.status == OfferStatus.Active && offer.offerer != address(0), "Offer is not active");
        require(dai.balanceOf(msg.sender) >= _price, "Insufficient funds"); 
        offer.price = _price;

        emit OfferUpdated(_listingId, msg.sender, _price);
    }

}