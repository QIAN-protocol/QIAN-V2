// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

import "../interfaces/IOracle.sol";

contract MockOracle is IOracle {
    uint256 public price;

    constructor(uint256 mockPrice) public {
        price = mockPrice;
    }

    function getLatestPrice() external override view returns (uint256) {
        return price;
    }

    function setPrice(uint256 mockPrice) public {
        price = mockPrice;
    }
}