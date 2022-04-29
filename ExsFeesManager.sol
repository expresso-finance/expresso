// SPDX-License-Identifier: none
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ExsFeesManager is Ownable {
   mapping(uint=>uint[]) private _chainFees;
   mapping(uint32=>uint32) private _contractIndex; // contract Id (defined off-chain) -> index

   function getChainFee(uint chainId, uint32 contractId) public view returns(uint){
      return _chainFees[chainId][_contractIndex[contractId]];
   }
   function setChainFee(uint chainId, uint32 contractId, uint fee) external onlyOwner{
      _chainFees[chainId][_contractIndex[contractId]]=fee;
   }
   function setContractIndex(uint32 contractId, uint32 index) external onlyOwner{
      require(index>0,"Index must be greater then 0");
      _contractIndex[contractId]=index;
   }
}