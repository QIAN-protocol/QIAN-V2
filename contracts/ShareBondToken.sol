// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

import "./lib/openzeppelin-contracts/ERC20Burnable.sol";
import "./lib/openzeppelin-contracts/Initializable.sol";
import "./authority/Mintable.sol";
import "./authority/Blacklistable.sol";

contract ShareBondToken is Initializable, ERC20Burnable, Mintable, Blacklistable {
    event Minted(address indexed from, address indexed to, uint256 amount);

    uint256 constant public MAX_SUPPLY = 12000000000000000000000000;

    function initialize(address admin) public initializer {
        _ERC20("KUN Buffering Token", "KBT");
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

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        super._beforeTokenTransfer(from, to, amount);
        if (from == address(0)) { // When minting tokens
            require(totalSupply().add(amount) <= MAX_SUPPLY, "max-supply-exceeded");
        }
    }

    function _destroy(address account, uint256 amount) internal override {
        _burn(account, amount);
    }
}
