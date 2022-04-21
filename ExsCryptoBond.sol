// SPDX-License-Identifier: None
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract FvtCryptoBondFactory{
  address payable public owner;

  constructor(){
    owner = payable(msg.sender);
  }

  address[] public bondIssuers;

  function createBondIssuer(string memory _name, uint _supply, address _collateral, bool _allowMint, uint _collateralDecimals) external returns(address _bondIssuer){
    FvtCryptoBondIssuer bondIssuer = new FvtCryptoBondIssuer(_name, _supply, _collateral, _allowMint, _collateralDecimals, owner);
    bondIssuers.push(address(bondIssuer));
    _bondIssuer = address(bondIssuer);
  }
}


contract FvtCryptoBondIssuer{
  address payable public owner;
  address public collateral; // The token as collateral for the bonds
  
  uint public totalSupply; // total number of bond uints
  uint public emittedSupply; // number of bond uints emitted
  uint internal _decimals; // needs to be the collateral token number of decimals
  string public name; 
  bool public allowMint; // boolean true/false

  event BondIssued(address indexed beneficiary, Bond indexed bond);
  event Withdraw(address indexed beneficiary, Bond indexed bond, uint indexed amount);
  
  string private _notAllowedMessage = "You are not allowed to do this operation";

  mapping(uint => bool) public allowedPeriods;
  mapping(uint => uint) public periodsROI; // %
  
  mapping(address => bool) public blacklisted; // blacklisted addresses

  constructor(string memory _name, uint _supply, address _collateral, bool _allowMint, uint _collateralDecimals, address payable _owner) {
    owner = _owner;
    name = _name;
    collateral = _collateral;
    allowMint = _allowMint;
    _decimals = _collateralDecimals;
    totalSupply = _supply*(10**_decimals);
  }

  struct Bond {
    uint period;
    uint end;
    uint bondUnits;
    uint initialBondUnits;
  }

  mapping(address => Bond[]) internal _holders;

  function createFvtCryptoBond(uint _period, uint _amount) external{
    require(blacklisted[msg.sender]==false, _notAllowedMessage); // checks if the entered issuer is valid
    require(allowedPeriods[_period]==true, _notAllowedMessage); // checks if the entered period is allowed
  
    _amount = _amount*(10**_decimals);
    uint finalAmount =  _amount+((_amount/100)*periodsROI[_period]); // adds the interests to the amount
    
    require(this.availableSupply()>=finalAmount, "Insufficient availability"); // checks if there is enough suppply in the smart contract
    
    IERC20(collateral).transferFrom(msg.sender, payable(owner), (_amount)); // transfers the collaterals to the bond issuer wallet

    emittedSupply += finalAmount; // updates emittedSupply
    Bond memory bond = Bond({ // creates the bond data
      period: _period,
      end: block.timestamp + (_period * (1 days)),
      bondUnits: finalAmount,
      initialBondUnits: _amount
    });
    _holders[msg.sender].push(bond); // adds record (IMPORTANT)

    emit BondIssued(msg.sender, bond);
  }

  function mint(uint _amount) external{
    require(allowMint == true, "Minting is not allowed for this contract");
    totalSupply+=_amount*(10**_decimals);
  }

  function setPeriodROI(uint _period, uint _roi) external {
    require(msg.sender==owner, _notAllowedMessage);
    require(owner!=address(0), _notAllowedMessage);
    periodsROI[_period] = _roi;
  }

  function changeOwnership(address payable _newOwner) external {
    require(msg.sender==owner, _notAllowedMessage);
    require(owner!=address(0), _notAllowedMessage);
    owner=_newOwner;
  }

  function removeOwnership() external {
    require(msg.sender==owner, _notAllowedMessage);
    require(owner!=address(0), _notAllowedMessage);
    owner= payable(address(0));
  }

  function addAllowedPeriod(uint _period) external {
    require(msg.sender==owner, _notAllowedMessage);
    require(owner!=address(0), _notAllowedMessage);
    allowedPeriods[_period] = true;
  }

  function removeAllowedPeriod(uint _period) external {
    require(msg.sender==owner, _notAllowedMessage);
    require(owner!=address(0), _notAllowedMessage);
    allowedPeriods[_period] = false;
  }

  function availableSupply() view public returns(uint _supply){
    _supply = totalSupply - emittedSupply;
  }

  function bondUnits(address _holder, uint _index) view public returns(uint _units){
    _units = _holders[_holder][_index].bondUnits;
  }
  function bondEnd(address _holder, uint _index) view public returns(uint _end){
    _end = _holders[_holder][_index].end;
  }
  function bondPeriod(address _holder, uint _index) view public returns(uint _period){
    _period = _holders[_holder][_index].period;
  }
  function holderNumOfBonds(address _holder) view public returns(uint _nBonds){
    _nBonds = _holders[_holder].length;
  }

  function collateralSupply() view public returns(uint _supply){
    _supply = IERC20(collateral).balanceOf(address(this));
  }

  function withdraw(uint _index, uint _amount) external {
    require(block.timestamp >= _holders[msg.sender][_index].end, "Not allowed: Still locked");
    require(_holders[msg.sender][_index].bondUnits >= _amount, "Insufficient balance");
    _amount = _amount*(10**_decimals);
    require(IERC20(collateral).balanceOf(address(this)) >= _amount, "Insufficient liquidity");
    _holders[msg.sender][_index].bondUnits -= _amount;
    IERC20(collateral).transfer(payable(msg.sender), (_amount));
    
    emit Withdraw(msg.sender, _holders[msg.sender][_index], _amount);
  }
  function withdrawAll(uint _index) external{
    require(block.timestamp >= _holders[msg.sender][_index].end, "Not allowed: Still locked");
    require(_holders[msg.sender][_index].bondUnits > 0, "You have 0 bond uints");
    uint funcAmount = _holders[msg.sender][_index].bondUnits;
    require(IERC20(collateral).balanceOf(address(this)) >= funcAmount, "Insufficient liquidity");
    _holders[msg.sender][_index].bondUnits = 0;
    IERC20(collateral).transfer(payable(msg.sender), funcAmount);

    emit Withdraw(msg.sender, _holders[msg.sender][_index], funcAmount);
  }
}