// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

import "../lib/openzeppelin-contracts/SafeMath.sol";
import "../lib/dodoex/IDVM.sol";
import "../interfaces/IERC20Decimals.sol";

// fixed window oracle that recomputes the average price for the entire period once every period
// note that the price average is only guaranteed to be over at least 1 period, but may be over a longer period
contract DodoexPairOracle {
    using SafeMath for uint256;

    uint256 public PERIOD = 3600; 

    IDVM public pair;
    uint256 public price0CumulativeLast;
    uint32 public blockTimestampLast;
    uint256 public price0Average;

    uint256 public QUOTE_TOKEN_PRECISION;
    uint256 public BASE_TOKEN_PRECISION;

    constructor(IDVM _pair) public {
        pair = _pair;
        price0CumulativeLast = pair._BASE_PRICE_CUMULATIVE_LAST_();
        blockTimestampLast = pair._BLOCK_TIMESTAMP_LAST_();
        (uint256 reserve0, uint256 reserve1) = pair.getVaultReserve();
        require(reserve0 != 0 && reserve1 != 0, "no-reserves");
        QUOTE_TOKEN_PRECISION = (10 ** uint256(IERC20Decimals(pair._QUOTE_TOKEN_()).decimals()));
        BASE_TOKEN_PRECISION = (10 ** uint256(IERC20Decimals(pair._BASE_TOKEN_()).decimals()));
    }

    function update() external {
        uint256 price0Cumulative = pair._BASE_PRICE_CUMULATIVE_LAST_();
        uint32 blockTimestamp = pair._BLOCK_TIMESTAMP_LAST_();
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // Overflow is desired
        // Ensure that at least one full period has passed since the last update
        require(timeElapsed >= PERIOD, "update-period-not-elapsed");
        price0Average = price0Cumulative.sub(price0CumulativeLast).div(timeElapsed);
        price0CumulativeLast = price0Cumulative;
        blockTimestampLast = blockTimestamp;
    }

    //1 QSD => X BUSD
    function consult() public view returns (uint256 amountOut) {
        amountOut = price0Average.mul(BASE_TOKEN_PRECISION).div(QUOTE_TOKEN_PRECISION);
    }
}
