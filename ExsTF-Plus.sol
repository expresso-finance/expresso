// SPDX-License-Identifier: none
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract ERC20Exs is ERC20, ERC20Burnable, Ownable, Pausable {

    bool public pausable;
    bool public burnable;
    bool public mintable;
    address beneficiary;
    uint internal _fee;

    receive() external payable {}

    constructor(string memory _name, string memory _symbol, uint _premint, uint fee, bool _mintable, bool _pausable, bool _burnable) payable ERC20(_name, _symbol) {
        _fee=fee*10**12;
        pausable=_pausable;
        burnable=_burnable;
        mintable=_mintable;
        require(msg.value==_fee, "Invalid transaction value");
        beneficiary = payable(0xEF17013951D26f3F7F94272dd1F65D8696235D19);
        (bool sent, bytes memory data) = beneficiary.call{value: msg.value}("");
        require(sent, "Failed to send Ether");
        _mint(msg.sender, _premint * 10 ** decimals());
    }

    function pause() public onlyOwner {
        require(pausable, "This funcitonality is disabled");
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(mintable, "This funcitonality is disabled");
        _mint(to, amount);
    }

    function burn(uint256 amount) public override(ERC20Burnable){
        require(burnable, "This funcitonality is disabled");
        _burn(msg.sender,amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}
