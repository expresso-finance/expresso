// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ExsReferral is Ownable{
    mapping (uint32=>address) private _codesReferrals;
    mapping (address=>uint32) private _referralCodes;
    mapping (address=>bool) private _registeredReferrals;
    uint32 private _referralCodeBase = 127543; // max uint32 value 4,294,967,295
    uint32 private _codesCount;

    modifier onlyIfRegistered(){
        require(isRegistered(msg.sender)==true, "This account is not a referral");
        _;
    }
    modifier onlyIfNotRegistered(){
        require(isRegistered(msg.sender)==false, "This account is already a referral");
        _;
    }

    function getReferralCode(address account)
        public
        view
        returns(uint32)
    {
        return _referralCodes[account];
    }
    function getReferralAddress(uint32 code)
        public
        view
        returns(address)
    {
        return _codesReferrals[code];
    }
    
    function register()
        external
        onlyIfNotRegistered
    {
        _codesCount+=1;
        uint32 code=_referralCodeBase+_codesCount;
        _codesReferrals[code]=msg.sender;
        _referralCodes[msg.sender]=code;
        _registeredReferrals[msg.sender]=true;
    }
    function unregister()
        external
        onlyIfRegistered
    {
        _codesReferrals[_referralCodes[msg.sender]]=address(0);
        _referralCodes[msg.sender]=0;
        _registeredReferrals[msg.sender]=false;
    }

    function removeReferralFromAccount(address account)
        external
        onlyOwner
    {
        _registeredReferrals[account]=false;
        _codesReferrals[_referralCodes[account]]=address(0);
        _referralCodes[account]=0;
    }
    function removeReferralFromCode(uint32 code)
        external
        onlyOwner
    {
        _registeredReferrals[_codesReferrals[code]]=false;
        _referralCodes[_codesReferrals[code]]=0;
        _codesReferrals[code]=address(0);
    }

    function isRegistered(address account)
        public
        view
        returns(bool)
    {
        return(_registeredReferrals[account]);
    }
}