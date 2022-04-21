// SPDX-License-Identifier: none
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ExsTimeLock {
  uint public duration;
  uint public end;
  address payable public owner;

  constructor(uint durationInDays) payable{
    duration=durationInDays * 1 days;
    end = block.timestamp + duration;
    owner = payable(msg.sender);
  }

  receive() external payable {}

  function withdrawToken(uint amount, address token) external {
    require(msg.sender == owner, "Not allowed: Caller is not owner");
    require(block.timestamp >= end, "Not allowed: Still locked");
    require(amount <= IERC20(token).balanceOf(address(this)), "Not enough funds");
    IERC20(token).transfer(owner, amount);
  }

  function withdraw(uint amount) payable external{
    require(msg.sender == owner, "Not allowed: Caller is not owner");
    require(block.timestamp >= end, "Not allowed: Still locked");
    require(amount <= address(this).balance, "Not enough funds");
    (bool sent, bytes memory data) = owner.call{value: amount}("");
    require(sent, "Failed to send Ether");
  }

  function getTokenBalance(address token) view external returns(uint _balance){
    _balance = IERC20(token).balanceOf(address(this));
  }
  function getBalance() view external returns(uint _balance){
    _balance = address(this).balance;
  }
}