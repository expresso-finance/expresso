// SPDX-License-Identifier: none
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ExsIntermediary is ReentrancyGuard {
    using SafeERC20 for IERC20;

    event TransferToken(
        ERC20 token,
        address seder,
        address from,
        address to,
        uint amount
    );

    function receiveTokensFromOrigin(ERC20 token, uint amount) external nonReentrant{
        token.transferFrom(tx.origin,msg.sender,amount);
        emit TransferToken(token,msg.sender,tx.origin,msg.sender,amount);
    }

    function transferTokenFromOrigin(ERC20 token, address to, uint amount) external nonReentrant{
        token.transferFrom(tx.origin,to,amount);
        emit TransferToken(token,msg.sender,tx.origin,to,amount);
    }
}
