const REToken = artifacts.require("REToken")
const Marketplace = artifacts.require("Marketplace")
const DAI = artifacts.require("DAI")
const { expectRevert, expectEvent, BN } = require('@openzeppelin/test-helpers');

contract("Marketplace", (accounts) => {
    let token;
    let marketplace;
    let seller;
    let buyer;

    before(async () => {
        token = await REToken.deployed()
        marketplace = await Marketplace.deployed()
        accounts = await web3.eth.getAccounts()
        seller = accounts[1]
        buyer = accounts[2]
    })

    it("should be able to create a listing", async () => {
        await expectRevert(marketplace.createSale(1, 10, 1, { from: seller }), "Account hasn't approved the marketplace");
        await expectRevert(marketplace.approveMarketplaceToken({ from: seller }), "Has not approved the marketplace to ERC1155 contract")
        await token.setApprovalForAll(marketplace.address, true, { from: seller })
        await marketplace.approveMarketplaceToken({ from: seller })
        await expectRevert(marketplace.createSale(1, 10, 1, { from: seller }), "Insufficient tokens");
        await token.mint(accounts[1], 1, 100, "0x0")


        const result = await marketplace.createSale(1, 10, 1, { from: seller })
        expectEvent(result, "SaleCreated", { tokenId: "1", seller: seller, amount: "10", price: "1" })
        const listing = await marketplace.allListings(1)
        expect(listing.tokenId.toNumber()).to.equal(1)
        expect(listing.amount.toNumber()).to.equal(10)
        expect(listing.price.toNumber()).to.equal(1)
        expect(listing.seller).to.equal(seller)
        expect(listing.status.toNumber()).to.equal(0)
        expect(listing.numOffers.toNumber()).to.equal(0)
    })

    it("should be able to cancel listing", async () => {
        await marketplace.createSale(1, 20, 2, { from: seller })
        await expectRevert(marketplace.cancelSale(2), "Only seller can modify listing")
        await marketplace.cancelSale(2, { from: seller })
        const listing = await marketplace.allListings(2)
        expect(listing.status.toNumber()).to.equal(2)
        await expectRevert(marketplace.cancelSale(2, { from: seller }), "Listing is not active")
    })

    it("should be able to update listing", async () => {
        await expectRevert(marketplace.updateSale(1, 10, 2), "Only seller can modify listing")
        await expectRevert(marketplace.cancelSale(2, { from: seller }), "Listing is not active")
        await expectRevert(marketplace.updateSale(1, 110, 2, { from: seller }), "Insufficient tokens")

        const result = await marketplace.updateSale(1, 20, 5, { from: seller })
        expectEvent(result, "UpdatedSale", { listingId: "1", seller: seller, amount: "20", price: "5" })
        const listing = await marketplace.allListings(1)
        expect(listing.amount.toNumber()).to.equal(20)
        expect(listing.price.toNumber()).to.equal(5)
    })

    it("should be able to buy token listed", async () => {
        await expectRevert(marketplace.buyToken(2, { value: 2 }), "Listing is not active")

        let sellerBalance = await token.balanceOf(seller, 1)
        let buyerBalance = await token.balanceOf(buyer, 1)
        expect(sellerBalance.toNumber()).to.equal(100)
        expect(buyerBalance.toNumber()).to.equal(0)

        const result = await marketplace.buyToken(1, { from: buyer, value: 5 })
        expectEvent(result, "TokenPurchased", { listingId: "1", buyer: buyer, seller: seller, amount: "20", price: "5" })
        sellerBalance = await token.balanceOf(seller, 1)
        buyerBalance = await token.balanceOf(buyer, 1)
        expect(sellerBalance.toNumber()).to.equal(80)
        expect(buyerBalance.toNumber()).to.equal(20)

        const listing = await marketplace.allListings(1)
        expect(listing.status.toNumber()).to.equal(1)
    })
})

contract("Marketplace", () => {
    let token;
    let dai;
    let marketplace;
    let seller;
    let buyer;

    before(async () => {
        token = await REToken.deployed()
        dai = await DAI.deployed()
        marketplace = await Marketplace.deployed()
        accounts = await web3.eth.getAccounts()
        seller = accounts[1]
        buyer = accounts[2]

        await token.setApprovalForAll(marketplace.address, true, { from: seller })
        await marketplace.approveMarketplaceToken({ from: seller })
        await token.mint(accounts[1], 1, 100, "0x0")
    })

    it("should create an offer for a listing", async () => {
        await expectRevert(marketplace.createOffer(1, 20, {from:buyer}), "Listing is not active")
        await marketplace.createSale(1, 10, 50, { from: seller })
        await expectRevert(marketplace.createOffer(1, 10, {from: buyer}),"Has not approved marketplace to their DAI")
        await expectRevert(marketplace.approveMarketplaceDAI({from:buyer}), "Hasn't approved marketplace to ERC20 contract")
        await dai.approve(marketplace.address, web3.utils.toBN("1000000000000000000"), {from: buyer})
        await marketplace.approveMarketplaceDAI({from: buyer})
        await expectRevert(marketplace.createOffer(1, 10, {from: buyer}),"Offerer has insufficient funds")
        await dai.mint(buyer, 100);

        const result = await marketplace.createOffer(1, 10, {from: buyer})  
        expectEvent(result, "OfferCreated", {listingId: "1", offerer: buyer, price: "10"})
        const offer = await marketplace.listingToOffers(1,1)
        expect(offer.offerer).to.equal(buyer)
        expect(offer.price.toNumber()).to.equal(10)
    })

    it("should cancel an offer", async () => {
        await marketplace.createOffer(1, 10, {from: buyer})
        await expectRevert(marketplace.cancelOffer(1,2), "Not the offerer of this offer")  
        await marketplace.cancelOffer(1, 2, {from: buyer})
        const offer = await marketplace.listingToOffers(1,2)
        expect(offer.status.toNumber()).to.equal(1)
    })

    it("should update an offer", async () => {
        await marketplace.createOffer(1, 10, {from: buyer})  
        await expectRevert(marketplace.updateOffer(1, 1, 40, {from: seller}), "Not the offerer of this offer")
        await expectRevert(marketplace.updateOffer(1, 2, 40, {from: buyer}), "Offer is not active")
        await expectRevert(marketplace.updateOffer(1, 1, 150, {from: buyer}), "Insufficient funds")
        
        const result = await marketplace.updateOffer(1, 1, 40, {from: buyer})
        expectEvent(result, "OfferUpdated", {listingId: "1", offerer: buyer, price: "40"})
        const offer = await marketplace.listingToOffers(1,1)
        expect(offer.price.toNumber()).to.equal(40)
    })

    it("should accept an offer", async () => {
        await expectRevert(marketplace.acceptOffer(1, 1), "Not seller")
        await expectRevert(marketplace.acceptOffer(1, 2, {from: seller}), "Offer is inactive")

        let sellerBalanceBefore = await dai.balanceOf(seller)
        let buyerBalanceBefore = await dai.balanceOf(buyer)
        const result = await marketplace.acceptOffer(1, 1, {from: seller})
        let sellerBalance = await dai.balanceOf(seller)
        let buyerBalance = await dai.balanceOf(buyer)
        expect(sellerBalance.toNumber() - sellerBalanceBefore.toNumber()).to.equal(40)
        expect(buyerBalanceBefore.toNumber() - buyerBalance.toNumber()).to.equal(40)
        expectEvent(result, "TokenPurchased",  { listingId: "1", buyer: buyer, seller: seller, amount: "10", price: "40" })
        
        const listing = await marketplace.allListings(1)
        expect(listing.status.toNumber()).to.equal(1)
    })

})