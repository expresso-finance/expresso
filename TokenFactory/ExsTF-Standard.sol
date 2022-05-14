// SPDX-License-Identifier: none
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Exs is ERC20 {
    address payable public beneficiary;
    uint internal _fee;
    constructor(string memory name, string memory symbol, uint premint, uint fee) payable ERC20(name, symbol) {
        _fee=fee*10**12;
        require(msg.value==_fee, "Invalid transaction value");
        beneficiary = payable(0xEF17013951D26f3F7F94272dd1F65D8696235D19);
        (bool sent, bytes memory data) = beneficiary.call{value: msg.value}("");
        require(sent, "Failed to send Ether");
        _mint(msg.sender, premint * 10 ** decimals());
    }
}
