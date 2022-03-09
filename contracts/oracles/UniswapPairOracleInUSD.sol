pragma solidity 0.6.11;

import "./UniswapOracle.sol";
import "../interfaces/IOracle.sol";

//WARNING: pairFor hash.
 
contract UniswapPairOracleInUSD is IOracle, UniswapOracle {
    using SafeMath for uint256;

    address public quotedToken;
    address public quotedTokenOracle;

    constructor(
        address _factory,
        address _tokenA,
        address _quotedToken,
        address _quotedTokenOracle
    ) public UniswapOracle(_factory, _tokenA, _quotedToken) {
        quotedToken = _quotedToken;
        quotedTokenOracle = _quotedTokenOracle;
    }

    function getLatestPrice() public view override returns (uint256) {
        uint256 quotedTokenInUsd = IOracle(quotedTokenOracle).getLatestPrice();
        return quotedTokenInUsd.mul(1e18).div(consult(quotedToken, 1e18));
    }
}