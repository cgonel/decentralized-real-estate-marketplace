// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.14;

/**
    @title Real Estate Token
*/

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract REToken is ERC1155, Ownable {
    constructor() ERC1155("http://localhost:3000/{id}.json") {
        _mint(msg.sender, 1, 10**18, "");
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data) public {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }
}