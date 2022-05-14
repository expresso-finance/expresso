// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "./ExsReferral.sol";
import "./ExsFeesManager.sol";
import "./ExsIntermediary.sol";

contract ExsReSale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    ExsFeesManager private _feeManager = ExsFeesManager(0x358AA13c52544ECCEF6B0ADD0f801012ADAD5eE3); // Smart contract where fee info are stored
    ExsReferral private _referralProgram = ExsReferral(0x7EF2e0048f5bAeDe046f6BF797943daF4ED8CB47); // Expresso referral program manager smart contract
    ExsIntermediary private _intermediary = ExsIntermediary(0xDA0bab807633f07f013f94DD0E6A4F96F8742B53);

    // referral program 
    mapping (address => uint) private _referrals; // amount raised by each referral codes
    uint private _raisedWithReferral; // total amount raised using a valid referral code
    uint8 private _contributionFee = 3; // % of total raised amount
    uint8 private _referralReward = 30; // % of _contributionFee on amount raised through referral codes

    mapping (address => uint256) private _balances;
    mapping (address => uint) private _contributions;
    mapping (address => bool) private _whitelist;

    ERC20 private _token;
    uint private _tokenAmount;
    bool private _whitelistActive;
    address payable private _vestingWallet;
    address payable private _feeBeneficiary = payable(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
    uint private _end; // timestamp (seconds)
    uint private _start; // timestamp (seconds)
    bool private _started;
    uint private _softCap;
    uint private _raised; // this variable will store the amount of coins raised after the pre-sale will be ended
    uint private _sold;
    bool private _claimed;
    bool private _isCanceled;
    bool private _isFinalized;
    uint private _minContribution;
    uint private _lockingTime; // seconds
    uint private _rate;

    // re-sale info
    struct ReSaleInfo{
        string logoUrl;
        string website;
        string facebook;
        string twitter;
        string github;
        string telegram;
        string instagram;
        string discord;
        string reddit;
        string description;
    }
    ReSaleInfo private _resaleinfo;

    uint8 constant private _UPCOMING=0;
    uint8 constant private _ACTIVE=1;
    uint8 constant private _COMPLETED=2;
    uint8 constant private _FINALIZED=3;
    uint8 constant private _CANCELED=4;

    uint32 constant private _CONTRACT_ID=2;

    constructor(
        ERC20 token,
        uint amount,
        ERC20 collateralToken,
        uint duration, // seconds
        uint start,
        uint softCap, // in collateral (in TKN not TKNbits where 1 TKN = 1*10**18 TKNbits)
        uint minContribution, // in collateral  (in TKN not TKNbits where 1 TKN = 1*10**18 TKNbits)
        bool whitelist,
        ReSaleInfo memory resaleinfo
    ) payable {
        require(start<=block.timestamp, "Start date-time must be after current date-time");
        require(msg.value==_feeManager.getChainFee(block.chainid,_CONTRACT_ID), "Invalid transaction value");
        require(minContribution<=softCap,"Minimum contirbution must be less or equal than the soft cap");
        (bool sent, bytes memory data) = _feeBeneficiary.call{value: msg.value}("");
        _minContribution=minContribution*10**18;
        _token=token;
        _tokenAmount=amount*10**18;
        _start=start;
        _end=start + duration;
        _softCap=softCap*10**18;
        _whitelistActive=whitelist;
        _resaleinfo = resaleinfo;
        _intermediary.receiveTokensFromOrigin(token, (_tokenAmount));
    }


    // events

    event contribution(
        uint oldAmount,
        uint newAmount,
        address indexed contributor
    );
    event tokenWithdrawed(
        uint amount,
        address indexed contributor
    );
    event prasaleCanceled();
    event resaleInfoEdited(
        ReSaleInfo oldInfo,
        ReSaleInfo newInfo
    );


    // modifiers

    modifier onlyIfActive(){
        require(status()==_ACTIVE, "Presale not active");
        _;
    }
    modifier onlyIfCompleted(){
        require(status()==_COMPLETED, "Presale not completed");
        _;
    }
    modifier onlyIfFinalized(){
        require(status()==_FINALIZED, "Presale not finalized");
        _;
    }
    modifier onlyIfCanceled(){
        require(status()==_CANCELED, "Presale not canceled");
        _;
    }
    modifier onlyIfWhitelisted(){
        require((_whitelist[msg.sender])||(_whitelistActive==false), "Address not in whitelist");
        _;
    }


    // write functions

    function updateRate(uint rate) onlyOwner external{
        _rate=rate;
    }

    /**
    * @notice Buy tokens that will be released at the end of the locking period.
    */
    function buyTokens(uint32 referralCode)
        external
        payable
        onlyIfActive
        onlyIfWhitelisted
        nonReentrant
    {
        require(msg.value>=_minContribution, "Value subceed minimum contribution");
        uint tokenAmount_ = ((msg.value*_rate)/(10**(18+_token.decimals())));
        require((_sold+tokenAmount_<=_tokenAmount), "Not enough tokens available");
        uint oldAmount_=_balances[msg.sender];
        _balances[msg.sender] += tokenAmount_;
        _sold += tokenAmount_;
        _contributions[msg.sender] += msg.value;
        address ref = _referralProgram.getReferralAddress(referralCode);
        if(ref!=address(0)){
            _referrals[ref] += msg.value;
            _raisedWithReferral += msg.value;
        }
        emit contribution(
            oldAmount_,
            _balances[msg.sender],
            msg.sender
        );
    }


    //read functions

    function balance() public view returns (uint256) {
        return _balances[msg.sender];
    }
    function cotributionAmount() public view returns (uint) {
        return _contributions[msg.sender];
    }
    function status() public view returns (uint8 status){
        if(block.timestamp<_start){
            status = _UPCOMING;
        }else if(block.timestamp>=_end){
            if(totalContributionAmount()>=_softCap){
                status = _COMPLETED;
            }else{
                status = _CANCELED;
            }
        }else if(_start<=block.timestamp&&block.timestamp<=_end){
            if(totalContributionAmount()>=_softCap){
                status = _COMPLETED;
            }else{
                status = _ACTIVE;
            }
        }else if(_isCanceled){
            status = _CANCELED;
        }

        if(_isFinalized){
            status = _FINALIZED;
        }

        return status;
    }
    function softCapAmount() public view returns (uint256) {
        return _softCap;
    }
    function endTimestamp() public view returns (uint256) {
        return _end;
    }
    function tokenAddress() public view returns (ERC20) {
        return _token;
    }
    function tokenAmount() public view returns (uint){
        return _token.balanceOf(address(this));
    }
    function totalContributionAmount() public view returns (uint256) {
        if(_claimed){
            return _raised;  
        }else{
            return address(this).balance;
        }
    }
    function sold() public view returns (uint) {
        return _sold;
    }
    function amountAvailable() public view returns (uint) {
        return (_tokenAmount-_sold);
    }
    function claimed() public view returns (bool) {
        return _claimed;
    }
}