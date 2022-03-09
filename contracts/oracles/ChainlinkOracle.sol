// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

import "../lib/chainlink/AggregatorV3Interface.sol";
import "../interfaces/IOracle.sol";

contract ChainlinkOracle is IOracle {
    AggregatorV3Interface public priceFeed;

    constructor(address initialPriceFeed) public {
        priceFeed = AggregatorV3Interface(initialPriceFeed);
    }

    function getLatestPrice() public override view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "invalid-chainlink-price");
        return uint256(price) * (10 ** (18 - uint256(priceFeed.decimals())));
    }
}
