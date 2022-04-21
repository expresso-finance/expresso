// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ExsPreSale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    mapping (address => uint256) private _balances;
    address payable private _vestingWallet;
    address payable private _feeBeneficiary = payable(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
    bool private _vestingForInvestors;
    ERC20 private _token;
    uint private _end; // timestamp
    uint private _softCap;
    uint private _hardCap;
    uint private _rate;
    uint private _fee;
    uint private _coefficent;
    uint private _singleTokenInBits;
    uint private _raised; // this variable will store the amount of coins raised after the pre-sale will be ended
    bool private _claimed;

    constructor(
        ERC20 token,
        uint duration, // seconds
        uint softCap,
        uint hardCap,
        uint rate, // how many wei for 1 token
        bool vestingForInvestors,
        uint coef,
        uint fee
    ) payable {
        _fee=fee*10**12;
        require(msg.value==_fee, "Invalid transaction value");
        (bool sent, bytes memory data) = _feeBeneficiary.call{value: msg.value}("");
        _token=token;
        _end=block.timestamp + duration;
        _softCap=softCap*10**18;
        _hardCap=hardCap*10**18;
        _vestingForInvestors=vestingForInvestors;
        _singleTokenInBits=10**(token.decimals());
        _rate=rate;
        _coefficent=coef*_singleTokenInBits;
        //token.transferFrom(msg.sender, address(this), ((_hardCap/_valueDividend)*_rateConverter));
    }


    // modifiers

    modifier onlyIfPresaleNotEnded(){
        require(block.timestamp < _end, "Not allowed: Presale ended");
        _;
    }
    modifier onlyIfPresaleEnded(){
        require(block.timestamp >= _end, "Not allowed: Presale not ended");
        _;
    }


    // write functions
    /**
    * @notice Buy tokens that will be released at the end of the pre-sale.
    */
    function buyTokens() external payable onlyIfPresaleNotEnded{
        require(((address(this).balance)+msg.value) <= _hardCap, "Not allowed: This amount exceeds the available tokens supply");
        _balances[msg.sender] += (msg.value*_coefficent)/(1*10**18);
    }

    /**
    * @notice Sends all the raised coins to the beneficiary address.
    */
    function claim()
        external
        nonReentrant
        onlyIfPresaleEnded
        onlyOwner
    {
        _raised=address(this).balance;
        (bool sent, bytes memory data) = msg.sender.call{value: address(this).balance}("");
        require(sent, "Failed to send");
        _claimed=true;
    }

    /**
    * @notice Sends all the tokens of an address to that address or to a vesting wallet.
    */
    function withdraw()
        external
        payable
        nonReentrant
        onlyIfPresaleEnded
    {
        if(_vestingForInvestors){
            _token.transfer(_vestingWallet, _balances[msg.sender]);
        }else{
            _token.transfer(msg.sender, _balances[msg.sender]);
        }
    }


    //read functions

    function getBalance(address account) public view returns (uint256) {
        return _balances[account];
    }
    function getSoftCap() public view returns (uint256) {
        return _softCap;
    }
    function getHardCap() public view returns (uint256) {
        return _hardCap;
    }
    function getRate() public view returns (uint256) {
        return _rate;
    }
    function endTimestamp() public view returns (uint256) {
        return _end;
    }
    function tokenAddress() public view returns (ERC20) {
        return _token;
    }
    function getTokenBalance() public view returns (uint){
        return _token.balanceOf(address(this));
    }
    function raisedAmount() public view returns (uint256) {
        if(_claimed){
            return _raised;  
        }else{
            return address(this).balance;
        }
    }
    function hasVestingForInvestors() public view returns (bool) {
        return _vestingForInvestors;
    }
    function claimed() public view returns (bool) {
        return _claimed;
    }
}