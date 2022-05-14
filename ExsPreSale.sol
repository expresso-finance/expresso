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


contract ExsVesting is VestingWallet {
    constructor(
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds
    ) VestingWallet(
        beneficiaryAddress,
        startTimestamp,
        durationSeconds
    ) {}
}

contract ExsPreSale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // smart contracts
    ExsFeesManager private _feeManager = ExsFeesManager(0x358AA13c52544ECCEF6B0ADD0f801012ADAD5eE3); // Smart contract where fee info are stored
    ExsReferral private _referralProgram = ExsReferral(0x7EF2e0048f5bAeDe046f6BF797943daF4ED8CB47); // Expresso referral program manager smart contract
    ExsIntermediary private _intermediary = ExsIntermediary(0xDA0bab807633f07f013f94DD0E6A4F96F8742B53);

    // referral program 
    mapping (address => uint) private _referrals; // amount raised by each referral codes
    uint private _raisedWithReferral; // total amount raised using a valid referral code
    uint8 private _contributionFee = 4; // % of total raised amount
    uint8 private _referralReward = 30; // % of _contributionFee on amount raised through referral codes

    mapping (address => uint256) private _balances;
    mapping (address => uint) private _investments;
    mapping (address => bool) private _whitelist;

    ERC20 private _token;
    bool private _whitelistActive;
    address payable private _vestingWallet;
    address payable private _feeBeneficiary = payable(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
    uint private _end; // timestamp (seconds)
    uint private _start; // timestamp (seconds)
    bool private _started;
    uint private _softCap;
    uint private _hardCap;
    uint private _rate; // how many wei for 1 token bit or vice-versa
    bool private _reverseRate; // if the token is worth more then the collateral this should be true
    uint private _raised; // this variable will store the amount of coins raised after the pre-sale will be ended
    bool private _claimed;
    bool private _isCanceled;
    bool private _isFinalized;
    uint private _minContribution;

    // vesting params
    struct Vesting{
        bool enabled;   
        address beneficiaryAddress;
        uint64 startTimestamp;
        uint64 durationSeconds;
    }
    struct VestingAddress{
        bool enabled;   
        ExsVesting vestingAddress;
    }
    VestingAddress private _contributorsVesting;
    VestingAddress private _teamVesting;

    // pre-sale info
    struct PresaleInfo{
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
    PresaleInfo private _presaleInfo;

    // rate info
    struct Rate{
        uint8 rate;
        bool reverseRate;
    }

    uint8 constant private _UPCOMING=0;
    uint8 constant private _ACTIVE=1;
    uint8 constant private _COMPLETED=2;
    uint8 constant private _FINALIZED=3;
    uint8 constant private _CANCELED=4;

    uint32 constant private _CONTRACT_ID=1;
    //address constant private _ROUTER_ADDRESS=0x10ED43C718714eb63d5aA57B78B54704E256024E;
    
    constructor(
        ERC20 token,
        uint duration, // seconds
        uint start,
        uint softCap, // in ether
        uint hardCap, // in ether
        uint minContribution, // in ether
        bool whitelist,
        Rate memory rate,
        Vesting memory contributorsVesting,
        Vesting memory teamVesting,
        PresaleInfo memory presaleInfo
    ) payable {
        require(start<=block.timestamp, "Start date-time must be after current date-time");
        require(softCap<=hardCap,"Softcap must be >= 50% of the Hardcap and <= Hardcap");
        require(softCap>=(hardCap/2),"Softcap must be >= 50% of the Hardcap and <= Hardcap");
        require(msg.value==_feeManager.getChainFee(block.chainid,_CONTRACT_ID), "Invalid transaction value");
        require(minContribution<=softCap,"Minimum contirbution must be less or equal than the soft cap");
        (bool sent, bytes memory data) = _feeBeneficiary.call{value: msg.value}("");
        _minContribution=minContribution*10**18;
        _token=token;
        _start=start;
        _end=start + duration;
        _softCap=softCap*10**18;
        _hardCap=hardCap*10**18;
        _whitelistActive=whitelist;
        _rate=rate.rate;
        _reverseRate=rate.reverseRate;
        _presaleInfo = presaleInfo;
        if(rate.reverseRate){
            _intermediary.receiveTokensFromOrigin(token, (_hardCap/_rate));
        }else{
            _intermediary.receiveTokensFromOrigin(token, (_hardCap*_rate));
        }
        if(contributorsVesting.enabled){
            _contributorsVesting.enabled=true;
            _contributorsVesting.vestingAddress = new ExsVesting(contributorsVesting.beneficiaryAddress,contributorsVesting.durationSeconds,contributorsVesting.startTimestamp);
        }
        if(teamVesting.enabled){
            _teamVesting.enabled=true;
            _teamVesting.vestingAddress = new ExsVesting(teamVesting.beneficiaryAddress,teamVesting.durationSeconds,teamVesting.startTimestamp);
        }
    }

    // events

    event invested(
        uint oldAmount,
        uint newAmount,
        address indexed contributor
    );
    event revertedInvestment(
        uint amount,
        address indexed contributor
    );
    event tokenWithdrawed(
        uint amount,
        address indexed contributor
    );
    event prasaleCanceled();
    event presaleInfoEdited(
        PresaleInfo oldInfo,
        PresaleInfo newInfo
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
    modifier onlyIfEnoughSupply(){
        require(((address(this).balance)+msg.value) <= _hardCap, "Not allowed: This amount exceeds the available tokens supply");
        _;
    }


    // write functions

    /**
    * @notice Buy tokens that will be released at the end of the pre-sale.
    */
    function buyTokens(uint32 referralCode)
        external
        payable
        onlyIfActive
        onlyIfWhitelisted
        nonReentrant
        onlyIfEnoughSupply
    {
        require(msg.value>=_minContribution, "Value subceed minimum contribution");
        uint oldAmount_=_balances[msg.sender];
        if(_reverseRate){
            _balances[msg.sender] += (msg.value/_rate);
        }else{
            _balances[msg.sender] += (msg.value*_rate);
        }
        _investments[msg.sender] += msg.value;
        address ref = _referralProgram.getReferralAddress(referralCode);
        if(ref!=address(0)){
            _referrals[ref] += msg.value;
            _raisedWithReferral += msg.value;
        }
        emit invested(
            oldAmount_,
            _balances[msg.sender],
            msg.sender
        );
    }

    /**
    * @notice Sends all the raised coins to the beneficiary address.
    */
    function claim()
        external
        nonReentrant
        onlyIfCompleted
        onlyOwner
    {
        _raised=address(this).balance;
        uint referralReward=(((_raisedWithReferral/100)*_contributionFee)/100)*_referralReward;
        uint calimable = (_raised-((_raised/100)*_contributionFee))-referralReward;
        (bool sent, bytes memory data) = msg.sender.call{value: calimable}("");
        require(sent, "Failed to send");
        _claimed=true;
    }

    function referralClaim()
        external
        nonReentrant
        onlyIfCompleted
    {
        require(_referralProgram.isRegistered(msg.sender), "This account is not a referral");
        require(_referrals[msg.sender]>0, "Amount raised with this referral is zero or has already been claimed");
        uint reward=(((_referrals[msg.sender]/100)*_contributionFee)/100)*_referralReward;
        (bool sent, bytes memory data) = msg.sender.call{value: reward}("");
        require(sent, "Failed to send");
        _referrals[msg.sender]=0;
    }

    /**
    * @notice Sends all the tokens of an address to that address or to a vesting wallet.
    */
    function withdraw()
        external
        payable
        nonReentrant
        onlyIfCompleted
    {
        if(_contributorsVesting.enabled){
            _token.transfer(address(_contributorsVesting.vestingAddress), _balances[msg.sender]);
        }else{
            _token.transfer(msg.sender, _balances[msg.sender]);
        }
        emit tokenWithdrawed(
            _balances[msg.sender],
            msg.sender
        );
        _balances[msg.sender]=0;
    }

    function cancelPresale()
        external
        onlyOwner
        onlyIfActive
    {
        _isCanceled=true;
        _raised=0;
    }
    function refundContribution()
        external
        nonReentrant
        onlyIfCanceled 
    {   
        (bool sent, bytes memory data) = msg.sender.call{value: _investments[msg.sender]}("");
        require(sent, "Failed to send");
        emit revertedInvestment(
            _investments[msg.sender],
            msg.sender
        );
        _investments[msg.sender]=0;
    }

    function finalizePresale()
        external
        onlyOwner
        onlyIfActive
    {
        require(address(this).balance>=_hardCap, "Hard cap not reached");
        _isFinalized=true;
    }

    function addToWhitelist(address account)
        external
        onlyOwner
    {
        require(_whitelistActive, "Whitelist not enabled");
        _whitelist[account]=true;
    }

    function removeFromWhitelist(address account)
        external
        onlyOwner
    {
        require(_whitelistActive, "Whitelist not enabled");
        _whitelist[account]=false;
    }

    function setInfo(
        uint fee,
        string memory logoUrl,
        string memory website,
        string memory facebook,
        string memory twitter,
        string memory github,
        string memory telegram,
        string memory instagram,
        string memory discord,
        string memory reddit,
        string memory description
        )
        external
        payable
        onlyOwner
        onlyIfActive
    {
        require(msg.value==fee, "Invalid transaction value");
        PresaleInfo memory oldInfo_=_presaleInfo;
        _presaleInfo = PresaleInfo(logoUrl,website,facebook,twitter,github,telegram,instagram,discord,reddit,description);
        emit presaleInfoEdited(
            oldInfo_,
            _presaleInfo
        );
    }


    //read functions

    function balance() public view returns (uint256) {
        return _balances[msg.sender];
    }
    function cotributionAmount() public view returns (uint) {
        return _investments[msg.sender];
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
            if(totalContributionAmount()>=_hardCap){
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
    function hardCapAmount() public view returns (uint256) {
        return _hardCap;
    }
    function convertionRate() public view returns (uint256) {
        return _rate;
    }
    function reverseRate() public view returns (bool) {
        return _reverseRate;
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
    function contributorsVestingEnabled() public view returns (bool) {
        return _contributorsVesting.enabled;
    }
    function claimed() public view returns (bool) {
        return _claimed;
    }
}