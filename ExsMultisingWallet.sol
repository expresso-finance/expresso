// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ExsMultisignWallet is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Transaction {
        address to;
        uint value;
        bool executed;
        uint numConfirmations;
        mapping(address=>bool) confirmations;
    }
    struct TokenTransaction {
        address to;
        uint value;
        ERC20 token;
        bool executed;
        uint numConfirmations;
        mapping(address=>bool) confirmations;
    }

    mapping(address=>bool) private _isOwner;

    mapping(uint=>Transaction) private _transactions;
    uint private _numberOfTransactions; 

    mapping(uint=>TokenTransaction) private _tokenTransactions;
    uint private _numberOfTokenTransactions;

    uint private _requestedConfirmations;

    constructor(
        address[] memory owners,
        uint requestedConfirmations
    ) payable {
        require(requestedConfirmations>0,"Requested confirmations must be greater then zero");
        require(requestedConfirmations<=owners.length, "Requested confirmations must be less or equal then the number of owners");
        _requestedConfirmations=requestedConfirmations;
        for(uint i=0; i<owners.length; i++){
            _isOwner[owners[i]]=true;
        }
    }


    //---------------modifiers---------------//

    modifier onlyIfOwner(){
        require(_isOwner[msg.sender]==true, "Not allowed: This account is not a Owner");
        _;
    }


    //---------------events---------------//

    event ProposeTransaction(
        address indexed to,
        uint value,
        address indexed proposer,
        uint index
    );
    event ConfirmTransaction(
        uint indexed txIndex,
        address indexed confirmedBy
    );
    event ExecuteTransaction(
        uint indexed txIndex
    );
    event ProposeTokenTransaction(
        address indexed to,
        ERC20 indexed token,
        uint value,
        address indexed proposer,
        uint index
    );
    event ConfirmTokenTransaction(
        uint indexed txIndex,
        address indexed confirmedBy
    );
    event ExecuteTokenTransaction(
        uint indexed txIndex
    );


    //---------------write functions---------------//

    function proposeTransaction(address to, uint value) external onlyIfOwner{
        _numberOfTransactions+=1;
        _transactions[_numberOfTransactions];
        _transactions[_numberOfTransactions].to=to;
        _transactions[_numberOfTransactions].value=value;

        emit ProposeTransaction(to, value, msg.sender, _numberOfTransactions);
    }

    function confirmTransaction(uint index) external onlyIfOwner{
        require(_transactions[index].confirmations[msg.sender]==false, "Already confirmed: This account already confirmed this transaction");
        _transactions[index].confirmations[msg.sender]=true;
        _transactions[index].numConfirmations+=1;
        emit ConfirmTransaction(index,msg.sender);
    }

    function executeTransaction(uint index) external nonReentrant onlyIfOwner{
        require(_transactions[index].numConfirmations>=_requestedConfirmations, "Not allowed: Not enough confirmations");
        (bool sent, bytes memory data) = _transactions[index].to.call{value: _transactions[index].value}("");
        require(sent, "Failed to send");
        _transactions[index].executed=true;

        emit ExecuteTransaction(index);
    }


    // token transactions

    function proposeTokenTransaction(address to, uint value, ERC20 token) external onlyIfOwner{
        require(token!=ERC20(address(0)));
        _numberOfTokenTransactions+=1;
        _tokenTransactions[_numberOfTokenTransactions];
        _tokenTransactions[_numberOfTokenTransactions].token=token;
        _tokenTransactions[_numberOfTokenTransactions].to=to;
        _tokenTransactions[_numberOfTokenTransactions].value=value;

        emit ProposeTokenTransaction(to, token, value, msg.sender, _numberOfTokenTransactions);
    }

    function confirmTokenTransaction(uint index) external onlyIfOwner{
        require(_tokenTransactions[index].confirmations[msg.sender]==false, "Already confirmed: This account already confirmed this transaction");
        _tokenTransactions[index].confirmations[msg.sender]=true;
        _tokenTransactions[index].numConfirmations+=1;

        emit ConfirmTokenTransaction(index,msg.sender);
    }

    function executeTokenTransaction(uint index) external nonReentrant onlyIfOwner{
        require(_tokenTransactions[index].numConfirmations>=_requestedConfirmations, "Not allowed: Not enough confirmations");
        _tokenTransactions[index].token.transfer(_tokenTransactions[index].to,_tokenTransactions[index].value);
        _tokenTransactions[index].executed=true;

        emit ExecuteTokenTransaction(index);
    }
    //---------------read functions---------------//

    function getTransactionValue(uint index) public view onlyIfOwner returns(uint){
        return _transactions[index].value;
    }
    function getTransactionReceiver(uint index) public view onlyIfOwner returns(address){
        return _transactions[index].to;
    }
    function getTransactionExecuted(uint index) public view onlyIfOwner returns(bool){
        return _transactions[index].executed;
    }
    function getTransactionNumberOfConfirmations(uint index) public view onlyIfOwner returns(uint){
        return _transactions[index].numConfirmations;
    }
    function getTransactionConfirmedBy(uint index, address owner) public view onlyIfOwner returns(bool){
        return _transactions[index].confirmations[owner];
    }
    function balance() public view onlyIfOwner returns(uint){
        return address(this).balance;
    }
    function tokenBalance(ERC20 token) public view onlyIfOwner returns(uint){
        return token.balanceOf(address(this));
    }
    function getOwners(address account) public view onlyIfOwner returns(bool){
        return _isOwner[account];
    }
}