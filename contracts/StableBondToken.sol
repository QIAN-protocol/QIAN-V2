// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

import "./lib/openzeppelin-contracts/ERC20Burnable.sol";
import "./lib/openzeppelin-contracts/Initializable.sol";
import "./authority/Mintable.sol";
import "./authority/Blacklistable.sol";

contract StableBondToken is Initializable, ERC20Burnable, Mintable, Blacklistable {
    event Minted(address indexed from, address indexed to, uint256 amount);
    event Destroyed(address indexed from, address indexed to, uint256 amount);

    function initialize(address admin) public initializer {
        _ERC20("Dollar Bond QSD", "DBQ");
        _Owned(admin, msg.sender);
        _Mintable();
        _Blacklistable();
    }

    function mint(address account, uint256 amount) public onlyMinter {
        _mint(account, amount);
        emit Minted(msg.sender, account, amount);
    }

    function transfer(address recipient, uint256 amount) public override notBlacklisted(msg.sender) returns (bool) {
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override notBlacklisted(sender) returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    function _destroy(address account, uint256 amount) internal override {
        _burn(account, amount);
    }
}
