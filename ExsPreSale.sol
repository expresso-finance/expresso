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
    mapping (address => uint) private _referrals;
    mapping (address => uint) private _investments;
    mapping (address => bool) private _whitelist;
    bool private _whitelistActive;
    address payable private _vestingWallet;
    address payable private _feeBeneficiary = payable(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
    bool private _vestingForInvestors;
    ERC20 private _token;
    uint private _end; // timestamp (seconds)
    uint private _start; // timestamp (seconds)
    uint private _softCap;
    uint private _hardCap;
    uint private _rate;
    bool private _rateLessThenOne;
    uint private _fee;
    uint private _singleTokenInBits;
    uint private _raised; // this variable will store the amount of coins raised after the pre-sale will be ended
    bool private _claimed;
    bool private _isCanceled;
    bool private _isFinalized;

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

    enum Status{ UPCOMING, ACTIVE, COMPLETED, CANCELED }
    Status private _status;

    constructor(
        ERC20 token,
        uint tokenAmount, // in tknBits
        uint duration, // seconds
        uint softCap,
        uint hardCap,
        uint rate, // how many wei for 1 token
        bool vestingForInvestors,
        uint start,
        uint fee,
        bool whitelist,
        PresaleInfo memory presaleInfo
    ) payable {
        require(start<=block.timestamp, "Start date-time must be after current date-time");
        require(softCap<=hardCap,"Softcap must be >= 50% of the Hardcap and <= Hardcap");
        require(softCap>=(hardCap/2),"Softcap must be >= 50% of the Hardcap and <= Hardcap");
        _fee=fee*10**12;
        require(msg.value==_fee, "Invalid transaction value");
        (bool sent, bytes memory data) = _feeBeneficiary.call{value: msg.value}("");
        _token=token;
        _start=start;
        _end=start + duration;
        _softCap=softCap*10**18;
        _hardCap=hardCap*10**18;
        _vestingForInvestors=vestingForInvestors;
        _singleTokenInBits=10**(token.decimals());
        _whitelistActive=whitelist;
        _rate=rate;
        _presaleInfo = presaleInfo;
        token.transferFrom(msg.sender, address(this),tokenAmount);
    }

    // events

    event invested(
        uint oldAmount,
        uint newAmount,
        address indexed investor
    );
    event revertedInvestment(
        uint amount,
        address indexed investor
    );
    event tokenWithdrawed(
        uint amount,
        address indexed investor
    );
    event prasaleCanceled();
    event presaleInfoEdited(
        PresaleInfo oldInfo,
        PresaleInfo newInfo
    );

    // modifiers

    modifier onlyIfActive(){
        require(getStatus()==Status.ACTIVE, "Presale not active");
        _;
    }
    modifier onlyIfCompleted(){
        require(getStatus()==Status.COMPLETED, "Presale not completed");
        _;
    }
    modifier onlyIfCanceled(){
        require(getStatus()==Status.CANCELED, "Presale not canceled");
        _;
    }
    modifier onlyIfWhitelisted(){
        require(_whitelist[msg.sender]&&_whitelistActive, "Address not in whitelist");
        _;
    }


    // write functions
    /**
    * @notice Buy tokens that will be released at the end of the pre-sale.
    */
    function buyTokens()
        external
        payable
        onlyIfActive
        onlyIfWhitelisted
    {
        uint oldAmount_=_balances[msg.sender];
        require(((address(this).balance)+msg.value) <= _hardCap, "Not allowed: This amount exceeds the available tokens supply");
        _balances[msg.sender] += (msg.value*_rate);
        _investments[msg.sender] += msg.value;
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
        onlyIfCompleted
    {
        if(_vestingForInvestors){
            _token.transfer(_vestingWallet, _balances[msg.sender]);
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
    function revertInvestiment()
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

    function getBalance() public view returns (uint256) {
        return _balances[msg.sender];
    }
    function getInvestedAmount() public view returns (uint) {
        return _investments[msg.sender];
    }
    function getStatus() public view returns (Status status){
        if(block.timestamp<_start){
            status = Status.UPCOMING;
        }else if(block.timestamp>=_end){
            if(raisedAmount()>=_softCap||_isFinalized){
                status = Status.COMPLETED;
            }else{
                status = Status.CANCELED;
            }
        }else if(_start>=block.timestamp&&block.timestamp<=_end){
            status = Status.ACTIVE;
        }else if(_isCanceled){
            status = Status.CANCELED;
        }
        return status;
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