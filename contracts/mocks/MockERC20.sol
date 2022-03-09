// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

import "../lib/openzeppelin-contracts/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) public {
        _ERC20(name, symbol);
        _setupDecimals(decimals);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) public {
        _burn(account, amount);
    }
}
