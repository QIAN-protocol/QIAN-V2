// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

import "./DodoexPairOracle.sol";
import "../interfaces/IOracle.sol";

contract DodoexPairOracleInUSD is IOracle, DodoexPairOracle {
    using SafeMath for uint256;

    address public quoteOracle;

    constructor(IDVM _pair, address _quoteOracle) public DodoexPairOracle(_pair) {
        quoteOracle = _quoteOracle;
    }

    function getLatestPrice() public view override returns (uint256) {
        uint256 quotePrice = IOracle(quoteOracle).getLatestPrice();
        return consult().mul(1e18).div(quotePrice);
    }
}
