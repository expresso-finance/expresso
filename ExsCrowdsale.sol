// SPDX-License-Identifier: none
pragma solidity 0.5;

import "openzeppelin-solidity@2/contracts/crowdsale/Crowdsale.sol";
import "openzeppelin-solidity@2/contracts/token/ERC20/ERC20.sol";

contract DappTokenCrowdsale is Crowdsale {
    constructor(
    uint256 _rate,
    address payable _wallet,
    ERC20 _token
    )
    Crowdsale(_rate, _wallet, _token)
    public
    {}
}