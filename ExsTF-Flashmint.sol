// SPDX-License-Identifier: none
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";


contract ERC20Exs is ERC20, ERC20Burnable, Ownable, Pausable, ERC20FlashMint {

    bool public pausable;
    bool public burnable;
    bool public mintable;

    constructor(string memory _name, string memory _symbol, uint _premint, address _sender, bool _mintable, bool _pausable, bool _burnable) ERC20(_name, _symbol) {
        pausable=_pausable;
        burnable=_burnable;
        mintable=_mintable;
        _mint(_sender, _premint * 10 ** decimals());
    }

    function pause() public onlyOwner {
        require(pausable, 'This funcitonality is disabled');
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(mintable, 'This funcitonality is disabled');
        _mint(to, amount);
    }

    function burn(uint256 amount) public override(ERC20Burnable){
        require(burnable, 'This funcitonality is disabled');
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
