# Decentralized Real Estate Marketplace

Dwella Investing aims to have a marketplace where their users can trade tokens representing fractions of real estate properties in Ontario.

### Requirements
Users should be able to: 
- List their tokens for sale setting their own price and the amount of tokens
- Update and cancel their listing
- Make offers on the tokens
- Update and cancel their offer
- Purchase tokens listed for sale
- Accept an offer made on their listing
- Record all the transactions per user

## Contracts

The marketplace uses ERC1155 to allow for fractionalized ownership of real estate properties.

- `REToken` represents the real estate tokens (ERC1155) 
- `DAI` represents a stablecoin needed to allow for automatic transfer of value on offer approval
- `Marketplace` contains the code meeting the requirements
