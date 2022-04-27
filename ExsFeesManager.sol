// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ExsFeesManager is Ownable {
    mapping(uint32=>uint) private _chianFees;

    function getChainFee(uint32 chainId) public view returns(uint){
       return _chianFees[chainId];
    }
    function setChainFee(uint32 chainId, uint fee) external onlyOwner{
       _chianFees[chainId]=fee;
    }
}