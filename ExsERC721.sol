// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract MyToken is ERC721, ERC721Burnable, ERC721Holder {
    constructor() ERC721("MyToken", "MTK") {}


    function _baseURI() internal pure override returns (string memory) {
        return "#";
    }
}