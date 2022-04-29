// SPDX-License-Identifier: none
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ExsFeesManager is Ownable {
    mapping(uint=>uint) private _chainFees;

    function getChainFee(uint chainId) public view returns(uint){
       return _chainFees[chainId];
    }
    function setChainFee(uint chainId, uint fee) external onlyOwner{
       _chainFees[chainId]=fee;
    }
}