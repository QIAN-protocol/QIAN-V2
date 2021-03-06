// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import "./lib/openzeppelin-contracts/SafeMath.sol";
import "./lib/openzeppelin-contracts/Math.sol";
import "./lib/openzeppelin-contracts/EnumerableSet.sol";
import "./lib/openzeppelin-contracts/ReentrancyGuard.sol";
import "./lib/openzeppelin-contracts/Initializable.sol";
import "./lib/openzeppelin-contracts/SafeERC20.sol";

import "./interfaces/IERC20Decimals.sol";
import "./interfaces/IMintable.sol";
import "./interfaces/IBurnable.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IWrappedNativeToken.sol";

import "./authority/Lockable.sol";

contract Vault is Initializable, ReentrancyGuard, Lockable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    event MintCollateral(address indexed sender, address indexed collateralToken, uint256 collateralAmount, uint256 mintAmount, uint256 mintFeeAmount);
    event MintShare(address indexed sender, uint256 shareAmount, uint256 mintAmount);
    event MintCollateralAndShare(address indexed sender, address indexed collateralToken, uint256 collateralAmount, uint256 shareAmount, uint256 mintAmount, uint256 mintFeeCollateralAmount, uint256 globalCollateralRatio);
    event RedeemCollateral(address indexed sender, uint256 stableAmount, address indexed collateralToken, uint256 redeemAmount, uint256 redeemFeeAmount);
    event RedeemShare(address indexed sender, uint256 shareAmount, uint256 redeemAmount);
    event RedeemCollateralAndShare(address indexed sender, uint256 stableAmount, address indexed collateralToken, uint256 redeemCollateralAmount, uint256 redeemShareAmount, uint256 redeemCollateralFeeAmount, uint256 globalCollateralRatio);
    event RedeemStableBond(address indexed sender, uint256 stableBondAmount, uint256 stableAmount);
    event MintStableBond(address indexed sender, uint256 stableAmount, uint256 stableBondAmount);
    event ExchangeShareBond(address indexed sender, uint256 shareBondAmount);
    event Recollateralize(address indexed sender, uint256 recollateralizeAmount, address indexed collateralToken, uint256 paidbackShareAmount);
    event Buyback(address indexed sender, uint256 shareAmount, address indexed receivedCollateralToken, uint256 buybackAmount, uint256 buybackFeeAmount);

    address constant public NATIVE_TOKEN_ADDRESS = address(0x0000000000000000000000000000000000000000);
    uint256 constant public TARGET_PRICE = 1000000000000000000; //$1
    uint256 constant public SHARE_TOKEN_PRECISION = 1000000000000000000;    //1e18
    uint256 constant public STABLE_TOKEN_PRECISION = 1000000000000000000;   //1e18
    uint256 constant public DELAY_CLAIM_BLOCK = 3;  //prevent flash redeem!! 

    uint256 public redeemFee;               //?????????????????? [1e18] 0.45% => 4500000000000000
    uint256 public mintFee;                 //?????????????????? [1e18] 0.45% => 4500000000000000
    uint256 public buybackFee;              //?????????????????? [1e18] 0.45% => 4500000000000000
    uint256 public globalCollateralRatio;   //??????????????? [1e18] 1000000000000000000
    uint256 public stablePricePower;        //?????????????????????????????? 3
    uint256 public shareBondCeiling;        //???????????????????????????.
    uint256 public shareBondSupply;         //??????????????????????????????
    uint256 public lastRefreshTime;         //????????????????????????????????????.

    uint256 public refreshStep;             //???????????????????????????????????? [1e18] 0.05 => 50000000000000000
    uint256 public refreshPeriod;           //??????????????????????????????(seconds)
    uint256 public refreshBand;             //??????????????????????????? [1e18] 0.05 => 50000000000000000 

    address public stableToken;             //stable token
    address public shareToken;              //share token
    address public stableBondToken;         //??????????????????????????????, ??????????????????????????????.
    address public shareBondToken;          //??????????????????????????????, ??????????????????????????????
    address payable public protocolFund;    //????????????

    struct Collateral {
        bool deprecated;                    //????????????????????? 
        uint256 recollateralizeFee;         //?????????????????? [1e18]
        uint256 ceiling;                    //????????????????????????
        uint256 precision;                  //??????????????????
        address oracle;                     //?????????????????????
    }

    mapping(address => uint256) public lastRedeemBlock;         //?????????????????????????????????. account => block.number
    mapping(address => uint256) public redeemedShareBonds;      //??????????????????????????????share????????????. account => shareAmount
    mapping(address => uint256) public unclaimedCollaterals;    //???????????????????????????????????????????????????. collateralToken => collateralAmount
    mapping(address => mapping(address => uint256)) public redeemedCollaterals; //????????????????????????????????????????????????. account => token => amount
    
    address public shareTokenOracle;
    address public stableTokenOracle;
    
    EnumerableSet.AddressSet private collateralTokens;  //?????????????????????.
    mapping(address => Collateral) public collaterals;  //???????????????. collateralToken => Collateral 

    //fix: 2021-03-22
    address public wrappedNativeToken;    
    bool private _initializedv2;

    function initialize(
        address _stableToken,
        address _shareToken,
        address _stableBondToken,
        address _shareBondToken,
        address _admin,
        address _stableTokenOracle,
        address _shareTokenOracle
    ) public initializer {
        //_admin: ???????????????, ??????????????? owner.
        //msg.sender: ???????????????(owner), ??????????????????.
        _Owned(_admin, msg.sender); 
        _ReentrancyGuard();
        stableToken = _stableToken;
        shareToken = _shareToken;
        stableBondToken = _stableBondToken;
        shareBondToken = _shareBondToken;
        stableTokenOracle = _stableTokenOracle;
        shareTokenOracle = _shareTokenOracle;
        globalCollateralRatio = 1e18;
    }

    function initializev2(address _wrappedNativeToken) public {
        require(!_initializedv2, "contract is already initialized");
        wrappedNativeToken = _wrappedNativeToken;
        _initializedv2 = true;
    }

    //?????????????????????
    function calculateCollateralValue(address collateralToken, uint256 collateralAmount) public view returns (uint256) {
        return collateralAmount.mul(getCollateralPrice(collateralToken)).div(collaterals[collateralToken].precision); 
    }

    //??????????????????????????????????????????(???????????????)
    function calculateCollateralMintAmount(address collateralToken, uint256 collateralAmount) public view returns (uint256, uint256) {
        uint256 mintFeeAmount = collateralAmount.mul(mintFee).div(1e18);
        collateralAmount = collateralAmount.sub(mintFeeAmount);
        return (calculateCollateralValue(collateralToken, collateralAmount), mintFeeAmount);
    }

    //??????????????????????????????
    function calculateShareMintAmount(uint256 shareAmount) public view returns(uint256) {
        return shareAmount.mul(getShareTokenPrice()).div(SHARE_TOKEN_PRECISION);
    }

    //??????????????????????????????????????????
    //@RETURN1 ?????????
    //@RETURN2 ???????????????????????????
    //@RETURN3 ???????????????????????????(???????????????)
    //@RETURN4 ???????????????????????????(???????????????)

    function calculateCollateralAndShareMintAmount(address collateralToken, uint256 collateralAmount) public view returns(uint256, uint256, uint256) {
        uint256 collateralValue = calculateCollateralValue(collateralToken, collateralAmount);
        uint256 shareTokenPrice = getShareTokenPrice();
        //https://docs.qian.finance/qian-v2-whitepaper/minting
        //(1 - Cr) * Cv = Cr * Sv
        //Sv = ((1 - Cr) * Cv) / Cr
        //   = (Cv - (Cv * Cr)) / Cr
        //   = (Cv / Cr) - ((Cv * Cr) / Cr)
        //   = (Cv / Cr) - Cv

        uint256 shareValue = collateralValue.mul(1e18).div(globalCollateralRatio).sub(collateralValue);
        uint256 shareAmount = shareValue.mul(SHARE_TOKEN_PRECISION).div(shareTokenPrice);

        uint256 mintFeeValue = collateralValue.mul(mintFee).div(1e18);
        uint256 mintFeeCollateralAmount = calculateEquivalentCollateralAmount(mintFeeValue, collateralToken);
        
        uint256 mintAmount = collateralValue.sub(mintFeeValue).add(shareValue); 
        return (mintAmount, shareAmount, mintFeeCollateralAmount);
    }

    //??????????????????????????????????????????(???????????????)
    function calculateCollateralRedeemAmount(uint256 stableAmount, address collateralToken) public view returns (uint256, uint256) {
        uint256 redeemAmount = calculateEquivalentCollateralAmount(stableAmount, collateralToken);
        uint256 redeemFeeAmount = redeemAmount.mul(redeemFee).div(1e18);
        return (redeemAmount.sub(redeemFeeAmount), redeemFeeAmount);
    }

    //??????????????????????????????(???????????????)
    function calculateShareRedeemAmount(uint256 stableAmount) public view returns (uint256) {
        uint256 shareAmount = stableAmount.mul(SHARE_TOKEN_PRECISION).div(getShareTokenPrice());
        return shareAmount;
    }

    //??????????????????????????????????????????.
    //@RETURN1 ??????????????????
    //@RETURN2 ??????????????????
    //@RETURN3 ???????????????????????????
    //@RETURN4 ???????????????????????????

    function calculateCollateralAndShareRedeemAmount(uint256 stableAmount, address collateralToken) public view returns (uint256, uint256, uint256) {
        uint256 collateralValue = stableAmount.mul(globalCollateralRatio).div(1e18);
        uint256 collateralAmount = calculateEquivalentCollateralAmount(collateralValue, collateralToken);

        uint256 shareValue = stableAmount.sub(collateralValue);
        uint256 shareAmount = shareValue.mul(SHARE_TOKEN_PRECISION).div(getShareTokenPrice());

        uint256 redeemFeeCollateralAmount = collateralAmount.mul(redeemFee).div(1e18);
        
        return (collateralAmount.sub(redeemFeeCollateralAmount), shareAmount, redeemFeeCollateralAmount);
    }

    //??????????????????????????????????????????
    //???: ?????????@stableToken???????????????$1, ??????@stableAmount??????????????????????????????.
    function calculateEquivalentCollateralAmount(uint256 stableAmount, address collateralToken) public view returns (uint256) {
        //stableAmount / collateralPrice
        return stableAmount.mul(collaterals[collateralToken].precision).div(getCollateralPrice(collateralToken));    //1e18
    }

    //????????????????????????????????????, ???????????????QSD????????????????????????. 
    //?????????????????????: QSD????????? * ($1 - QSD??????)
    function calculateAvailableStableBondAmount(uint256 stableAmount) public view returns(uint256) {
        uint256 stableTokenPrice = getStableTokenPrice();
        if(stableTokenPrice >= TARGET_PRICE)
            return 0;
        uint256 debt = IERC20(stableToken).totalSupply().mul(TARGET_PRICE.sub(stableTokenPrice)).div(1e18);
        uint256 bondAmount = debt.sub(Math.min(debt, IERC20(stableBondToken).totalSupply()));
        //x / x^3 = 1 / x^2
        uint256 exchangeRate = uint256(1e18 ** stablePricePower).div(stableTokenPrice ** (stablePricePower - 1));
        //check amount exceeds bond cap
        stableAmount = Math.min(stableAmount, bondAmount.mul(1e18).div(exchangeRate));
        return stableAmount.mul(exchangeRate).div(1e18);
    }

    //100% collateral-backed
    function mint(address collateralToken, uint256 collateralAmount, uint256 minimumReceived) external payable notLocked nonReentrant {
        require(isCollateralToken(collateralToken) && !collaterals[collateralToken].deprecated, "invalid/deprecated-collateral-token");
        require(globalCollateralRatio >= 1e18, "mint-not-allowed");
        (uint256 mintAmount, uint256 mintFeeAmount) = calculateCollateralMintAmount(collateralToken, collateralAmount);
        require(minimumReceived <= mintAmount, "slippage-limit-reached");
        require(getCollateralizedBalance(collateralToken).add(collateralAmount) <= collaterals[collateralToken].ceiling, "ceiling-reached");

        _depositFrom(collateralToken, msg.sender, collateralAmount);
        _withdrawTo(collateralToken, protocolFund, mintFeeAmount);

        IMintable(stableToken).mint(msg.sender, mintAmount);
        emit MintCollateral(msg.sender, collateralToken, collateralAmount, mintAmount, mintFeeAmount);
    }

    // 0% collateral-backed
    function mint(uint256 shareAmount, uint256 minimumReceived) external notLocked nonReentrant {
        require(globalCollateralRatio == 0, "mint-not-allowed");
        uint256 mintAmount = calculateShareMintAmount(shareAmount);
        require(minimumReceived <= mintAmount, "slippage-limit-reached");
        IBurnable(shareToken).burnFrom(msg.sender, shareAmount);
        IMintable(stableToken).mint(msg.sender, mintAmount);
        emit MintShare(msg.sender, shareAmount, mintAmount);
    }

    // > 0% and < 100% collateral-backed
    function mint(address collateralToken, uint256 collateralAmount, uint256 shareAmount, uint256 minimumReceived) external payable notLocked nonReentrant {
        require(isCollateralToken(collateralToken) && !collaterals[collateralToken].deprecated, "invalid/deprecated-collateral-token");
        require(globalCollateralRatio < 1e18 && globalCollateralRatio > 0, "mint-not-allowed");
        require(getCollateralizedBalance(collateralToken).add(collateralAmount) <= collaterals[collateralToken].ceiling, "ceiling-reached");
        (uint256 mintAmount, uint256 shareNeeded, uint256 mintFeeCollateralAmount) = calculateCollateralAndShareMintAmount(collateralToken, collateralAmount);
        require(minimumReceived <= mintAmount, "slippage-limit-reached");
        require(shareNeeded <= shareAmount, "need-more-shares");
        
        IBurnable(shareToken).burnFrom(msg.sender, shareNeeded);

        _depositFrom(collateralToken, msg.sender, collateralAmount);
        _withdrawTo(collateralToken, protocolFund, mintFeeCollateralAmount);

        IMintable(stableToken).mint(msg.sender, mintAmount);
        emit MintCollateralAndShare(msg.sender, collateralToken, collateralAmount, shareNeeded, mintAmount, mintFeeCollateralAmount, globalCollateralRatio);
    }

    // Redeem collateral. 100% collateral-backed
    function redeem(uint256 stableAmount, address receivedCollateralToken, uint256 minimumReceivedCollateralAmount) external notLocked nonReentrant {
        require(globalCollateralRatio == 1e18, "redeem-not-allowed");
        (uint256 redeemAmount, uint256 redeemFeeAmount) = calculateCollateralRedeemAmount(stableAmount, receivedCollateralToken);
        require(redeemAmount.add(redeemFeeAmount) <= getCollateralizedBalance(receivedCollateralToken), "not-enough-collateral");
        require(minimumReceivedCollateralAmount <= redeemAmount, "slippage-limit-reached");
        redeemedCollaterals[msg.sender][receivedCollateralToken] = redeemedCollaterals[msg.sender][receivedCollateralToken].add(redeemAmount);
        unclaimedCollaterals[receivedCollateralToken] = unclaimedCollaterals[receivedCollateralToken].add(redeemAmount);
        lastRedeemBlock[msg.sender] = block.number;
        IBurnable(stableToken).burnFrom(msg.sender, stableAmount);
        _withdrawTo(receivedCollateralToken, protocolFund, redeemFeeAmount);
        emit RedeemCollateral(msg.sender, stableAmount, receivedCollateralToken, redeemAmount, redeemFeeAmount);
    }

    // Redeem QSD for collateral and KUN. > 0% and < 100% collateral-backed
    function redeem(uint256 stableAmount, address collateralToken, uint256 minimumReceivedCollateralAmount, uint256 minimumReceivedShareAmount) external notLocked nonReentrant {
        require(globalCollateralRatio < 1e18 && globalCollateralRatio > 0, "redeem-not-allowed");
        (uint256 collateralAmount, uint256 shareAmount, uint256 redeemFeeCollateralAmount) = calculateCollateralAndShareRedeemAmount(stableAmount, collateralToken);
        require(collateralAmount.add(redeemFeeCollateralAmount) <= getCollateralizedBalance(collateralToken), "not-enough-collateral");
        require(minimumReceivedCollateralAmount <= collateralAmount && minimumReceivedShareAmount <= shareAmount, "collaterals/shares-slippage-limit-reached");
        redeemedCollaterals[msg.sender][collateralToken] = redeemedCollaterals[msg.sender][collateralToken].add(collateralAmount);
        unclaimedCollaterals[collateralToken] = unclaimedCollaterals[collateralToken].add(collateralAmount);
        redeemedShareBonds[msg.sender] = redeemedShareBonds[msg.sender].add(shareAmount);
        shareBondSupply = shareBondSupply.add(shareAmount);
        require(shareBondSupply <= shareBondCeiling, "sharebond-ceiling-reached");
        lastRedeemBlock[msg.sender] = block.number;
        IBurnable(stableToken).burnFrom(msg.sender, stableAmount);
        _withdrawTo(collateralToken, protocolFund, redeemFeeCollateralAmount);
        emit RedeemCollateralAndShare(msg.sender, stableAmount, collateralToken, collateralAmount, shareAmount, redeemFeeCollateralAmount, globalCollateralRatio);
    }

    // Redeem QSD for KUN. 0% collateral-backed
    function redeem(uint256 stableAmount, uint256 minimumReceivedShareAmount) external notLocked nonReentrant {
        require(globalCollateralRatio == 0, "redeem-not-allowed");
        uint256 shareAmount = calculateShareRedeemAmount(stableAmount);
        require(minimumReceivedShareAmount <= shareAmount, "slippage-limit-reached");
        redeemedShareBonds[msg.sender] = redeemedShareBonds[msg.sender].add(shareAmount);
        shareBondSupply = shareBondSupply.add(shareAmount);
        require(shareBondSupply <= shareBondCeiling, "sharebond-ceiling-reached");
        lastRedeemBlock[msg.sender] = block.number;
        IBurnable(stableToken).burnFrom(msg.sender, stableAmount);
        emit RedeemShare(msg.sender, stableAmount, shareAmount);
    }

    function claim() external notLocked nonReentrant {
        require(lastRedeemBlock[msg.sender].add(DELAY_CLAIM_BLOCK) <= block.number,"not-delay-claim-redeemed");
        uint256 length = collateralTokens.length();
        for (uint256 i = 0; i < length; ++i) {
            address collateralToken = collateralTokens.at(i);
            if (redeemedCollaterals[msg.sender][collateralToken] > 0) {
                uint256 collateralAmount = redeemedCollaterals[msg.sender][collateralToken];
                redeemedCollaterals[msg.sender][collateralToken] = 0;
                unclaimedCollaterals[collateralToken] = unclaimedCollaterals[collateralToken].sub(collateralAmount);
                _withdrawTo(collateralToken, msg.sender, collateralAmount);
            }
        }
        if (redeemedShareBonds[msg.sender] > 0) {
            uint256 shareAmount = redeemedShareBonds[msg.sender];
            redeemedShareBonds[msg.sender] = 0;
            IMintable(shareBondToken).mint(msg.sender, shareAmount);
        }
    }

    //???????????????????????????????????????????????????, ??????????????????????????????????????? ??????????????????????????????KUN????????????????????????KUN????????????.
    function recollateralize(address collateralToken, uint256 collateralAmount, uint256 minimumReceivedShareAmount) external payable notLocked nonReentrant {
        require(isCollateralToken(collateralToken) && !collaterals[collateralToken].deprecated, "deprecated-collateral-token");
        
        uint256 gapCollateralValue = getGapCollateralValue();
        require(gapCollateralValue > 0, "no-gap-collateral-to-recollateralize");
        uint256 recollateralizeValue = Math.min(gapCollateralValue, calculateCollateralValue(collateralToken, collateralAmount));
        uint256 paidbackShareAmount = recollateralizeValue.mul(uint256(1e18).add(collaterals[collateralToken].recollateralizeFee)).div(getShareTokenPrice());
        require(minimumReceivedShareAmount <= paidbackShareAmount, "slippage-limit-reached");
       
        uint256 recollateralizeAmount = recollateralizeValue.mul(1e18).div(getCollateralPrice(collateralToken));
        require(getCollateralizedBalance(collateralToken).add(recollateralizeAmount) <= collaterals[collateralToken].ceiling, "ceiling-reached");
        shareBondSupply = shareBondSupply.add(paidbackShareAmount);
        require(shareBondSupply <= shareBondCeiling, "sharebond-ceiling-reached");
        
        _depositFrom(collateralToken, msg.sender, collateralAmount);
        _withdrawTo(collateralToken, msg.sender, collateralAmount.sub(recollateralizeAmount));

        IMintable(shareBondToken).mint(msg.sender, paidbackShareAmount);
        emit Recollateralize(msg.sender, recollateralizeAmount, collateralToken, paidbackShareAmount);
    }

    //???????????????????????????????????????????????????, ??????????????????KUN???????????????????????????
    function buyback(uint256 shareAmount, address receivedCollateralToken) external notLocked nonReentrant {
        uint256 excessCollateralValue = getExcessCollateralValue();
        require(excessCollateralValue > 0, "no-excess-collateral-to-buyback");
        uint256 shareTokenPrice = getShareTokenPrice();
        uint256 shareValue = shareAmount.mul(shareTokenPrice).div(1e18); 
        uint256 buybackValue = excessCollateralValue > shareValue ? shareValue : excessCollateralValue;
        uint256 neededAmount = buybackValue.mul(1e18).div(shareTokenPrice);
        IBurnable(shareToken).burnFrom(msg.sender, neededAmount);
        uint256 buybackAmount = calculateEquivalentCollateralAmount(buybackValue, receivedCollateralToken);
        require(buybackAmount <= getCollateralizedBalance(receivedCollateralToken), "insufficient-collateral-amount");
        uint256 buybackFeeAmount = buybackAmount.mul(buybackFee).div(1e18);
        buybackAmount = buybackAmount.sub(buybackFeeAmount);

        _withdrawTo(receivedCollateralToken, msg.sender, buybackAmount);
        _withdrawTo(receivedCollateralToken, protocolFund, buybackFeeAmount);

        emit Buyback(msg.sender, shareAmount, receivedCollateralToken, buybackAmount, buybackFeeAmount);
    }

    //??????????????????????????????????????????, KUN????????????1:1?????????KUN:
    //  1. ???????????????????????????????????????????????????
    //  &&
    //  2. QSD??????????????????????????????(>$1)
    function exchangeShareBond(uint256 shareBondAmount) external notLocked nonReentrant {
        uint256 excessCollateralValue = getExcessCollateralValue();
        require(excessCollateralValue > 0, "no-excess-collateral-to-buyback");
        uint256 stableTokenPrice = getStableTokenPrice(); 
        require(stableTokenPrice > TARGET_PRICE, "price-not-eligible-for-bond-redeem");
        shareBondSupply = shareBondSupply.sub(shareBondAmount);
        IBurnable(shareBondToken).burnFrom(msg.sender, shareBondAmount);
        IMintable(shareToken).mint(msg.sender, shareBondAmount);
        emit ExchangeShareBond(msg.sender, shareBondAmount);
    }

    //???QSD????????????????????????(< $1), ????????????QSD?????????QSD??????.
    function mintStableBond(uint256 stableAmount, uint256 minimumReceivedBondAmount) public notLocked nonReentrant {
        uint256 stableTokenPrice = getStableTokenPrice();
        require(stableTokenPrice < TARGET_PRICE, "price-not-eligible-for-bond-purchase");    // < 1$
        uint256 bondAmount = calculateAvailableStableBondAmount(stableAmount);
        require(bondAmount > 0, "invalid-bond-amount");
        require(minimumReceivedBondAmount <= bondAmount, "slippage-limit-reached");
        IBurnable(stableToken).burnFrom(msg.sender, stableAmount);
        IMintable(stableBondToken).mint(msg.sender, bondAmount);
        emit MintStableBond(msg.sender, stableAmount, bondAmount);
    }

    //???QSD????????????????????????(< $1), ????????????QSD?????????1:1??????QSD
    function redeemStableBond(uint256 bondAmount) public notLocked nonReentrant {
        address bondToken = stableBondToken;
        uint256 stableTokenPrice = getStableTokenPrice();
        require(stableTokenPrice > TARGET_PRICE, "price-not-eligible-for-bond-redeem");
        uint256 availableStableAmount = IERC20(stableToken).totalSupply().mul(stableTokenPrice.sub(TARGET_PRICE)).div(1e18);
        availableStableAmount = Math.min(bondAmount, availableStableAmount);
        IBurnable(bondToken).burnFrom(msg.sender, availableStableAmount);
        IMintable(stableToken).mint(msg.sender, availableStableAmount);
        emit RedeemStableBond(msg.sender, bondAmount, availableStableAmount);
    }

    //?????????????????????.
    function refreshCollateralRatio() public notLocked {
        uint256 stableTokenPrice = getStableTokenPrice();
        require(block.timestamp - lastRefreshTime >= refreshPeriod, "refresh-cooling-period");
        if (stableTokenPrice > TARGET_PRICE.add(refreshBand)) { //decrease collateral ratio
            if (globalCollateralRatio <= refreshStep) {  
                globalCollateralRatio = 0;  //if within a step of 0, go to 0
            } else {
                globalCollateralRatio = globalCollateralRatio.sub(refreshStep);
            }
        } else if (stableTokenPrice < TARGET_PRICE.sub(refreshBand)) { //increase collateral ratio
            if (globalCollateralRatio.add(refreshStep) >= 1e18) {  
                globalCollateralRatio = 1e18; // cap collateral ratio at 1
            } else {
                globalCollateralRatio = globalCollateralRatio.add(refreshStep);
            }
        }
        lastRefreshTime = block.timestamp; // Set the time of the last expansion
    }

    function getNeededCollateralValue() public view returns(uint256) {
        uint256 stableSupply = IERC20(stableToken).totalSupply();
        // Calculates collateral needed to back each 1 QSD with $1 of collateral at current collat ratio
        return stableSupply.mul(globalCollateralRatio).div(1e18);
    }

    // Returns the value of excess collateral held in this pool, compared to what is needed to maintain the global collateral ratio
    function getExcessCollateralValue() public view returns (uint256) {
        uint256 totalCollateralValue = getTotalCollateralValue(); 
        uint256 neededCollateralValue = getNeededCollateralValue();
        if (totalCollateralValue > neededCollateralValue)
            return totalCollateralValue.sub(neededCollateralValue);
        return 0;
    }

    function getGapCollateralValue() public view returns(uint256) {
        uint256 totalCollateralValue = getTotalCollateralValue();
        uint256 neededCollateralValue = getNeededCollateralValue();
        if(totalCollateralValue < neededCollateralValue)
            return neededCollateralValue.sub(totalCollateralValue);
        return 0;
    }
    
    function getShareTokenPrice() public view returns(uint256) {
        return IOracle(shareTokenOracle).getLatestPrice();
    }
    function getStableTokenPrice() public view returns(uint256) {
        return IOracle(stableTokenOracle).getLatestPrice();
    }
    function getCollateralPrice(address token) public view returns (uint256) {
        return IOracle(collaterals[token].oracle).getLatestPrice();
    }

    function getTotalCollateralValue() public view returns (uint256) {
        uint256 totalCollateralValue = 0;
        uint256 length = collateralTokens.length();
        for (uint256 i = 0; i < length; ++i)
            totalCollateralValue = totalCollateralValue.add(getCollateralValue(collateralTokens.at(i)));
        return totalCollateralValue;
    }

    function getCollateralValue(address token) public view returns (uint256) {
        if(isCollateralToken(token))
            return getCollateralizedBalance(token).mul(getCollateralPrice(token)).div(collaterals[token].precision);
        return 0;
    }

    function isCollateralToken(address token) public view returns (bool) {
        return collateralTokens.contains(token);
    }

    function getCollateralTokens() public view returns (address[] memory) {
        uint256 length = collateralTokens.length();
        address[] memory tokens = new address[](length);
        for (uint256 i = 0; i < length; ++i)
            tokens[i] = collateralTokens.at(i);
        return tokens;
    }

    function getCollateralizedBalance(address token) public view returns(uint256) {
        address tt = (token == NATIVE_TOKEN_ADDRESS) ? wrappedNativeToken : token;
        uint256 balance = IERC20(tt).balanceOf(address(this));
        return balance.sub(Math.min(balance, unclaimedCollaterals[tt]));
    }

    function setStableTokenOracle(address newStableTokenOracle) public onlyOwner {
        stableTokenOracle = newStableTokenOracle;
    }

    function setShareTokenOracle(address newShareTokenOracle) public onlyOwner {
        shareTokenOracle = newShareTokenOracle;
    }

    function setRedeemFee(uint256 newRedeemFee) external onlyOwner {
        redeemFee = newRedeemFee;
    }

    function setMintFee(uint256 newMintFee) external onlyOwner {
        mintFee = newMintFee;
    }

    function setBuybackFee(uint256 newBuybackFee) external onlyOwner {
        buybackFee = newBuybackFee;
    }

    function addCollateralToken(address token, address oracle, uint256 ceiling, uint256 recollateralizeFee) external onlyOwner {
        require(collateralTokens.add(token) || collaterals[token].deprecated, "duplicated-collateral-token");
        if(token == NATIVE_TOKEN_ADDRESS) {
            collaterals[token].precision = 10**18;
        } else {
            uint256 decimals = IERC20Decimals(token).decimals();
            require(decimals <= 18, "unexpected-collateral-token");
            collaterals[token].precision = 10**decimals;
        }
        collaterals[token].deprecated = false;
        collaterals[token].oracle = oracle;
        collaterals[token].ceiling = ceiling;
        collaterals[token].recollateralizeFee = recollateralizeFee;
    }

    function deprecateCollateralToken(address token) external onlyOwner {
        require(isCollateralToken(token), "not-found-collateral-token");
        collaterals[token].deprecated = true;
    }

    function removeCollateralToken(address token) external onlyOwner {
        require(collaterals[token].deprecated, "undeprecated-collateral-token");
        collateralTokens.remove(token);
        delete collaterals[token];
    }

    function updateCollateralToken(address token, address newOracle, uint256 newCeiling, uint256 newRecollateralizeFee) public onlyOwner {
        require(isCollateralToken(token), "not-found-collateral-token");
        collaterals[token].ceiling = newCeiling;
        collaterals[token].oracle = newOracle;
        collaterals[token].recollateralizeFee = newRecollateralizeFee;
    }

    function setRefreshPeriod(uint256 newRefreshPeriod) external onlyOwner {
        refreshPeriod = newRefreshPeriod;
    }

    function setRefreshStep(uint256 newRefreshStep) external onlyOwner {
        refreshStep = newRefreshStep;
    }

    function setRefreshBand(uint256 newRefreshBand) external onlyOwner {
        refreshBand = newRefreshBand;
    }

    function setProtocolFund(address payable newProtocolFund) public onlyOwner {
        protocolFund =  newProtocolFund;
    }
    
    function setStablePricePower(uint256 newStablePricePower) public onlyOwner {
        stablePricePower = newStablePricePower;
    }

    function setGlobalCollateralRatio(uint256 newGlobalCollateralRatio) public onlyOwner {
        globalCollateralRatio = newGlobalCollateralRatio;
    }

    function setShareBondCeiling(uint256 newShareBondCeiling) public onlyOwner {
        shareBondCeiling = newShareBondCeiling;
    }

    function _withdrawTo(address token, address payable to, uint256 amount) internal {
        if(token == NATIVE_TOKEN_ADDRESS) {
            IWrappedNativeToken(wrappedNativeToken).withdraw(amount);
            to.transfer(amount);
        } else {
           IERC20(token).transfer(to, amount);
        }
    }

    function _depositFrom(address token, address from, uint256 amount) internal {
        if(token == NATIVE_TOKEN_ADDRESS) {
            require(msg.value == amount, "msg.value != amount");
            IWrappedNativeToken(wrappedNativeToken).deposit{value: amount}();
        } else {
           IERC20(token).transferFrom(from, address(this), amount);
        }
    }

    receive() external payable {
        require(msg.sender == wrappedNativeToken, "Only WXXX can send ether");
    }   
}
