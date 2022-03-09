# Chemix Labs: Innovative decentralized synthetic assets protocol


At present, it is generally believed in the industry that stablecoin has gone through five development stages based on technical architecture, which can be roughly divided into five generations:

+ The representatives of the first-generation of stablecoins are USDT, BUSD, etc., These stablecoins take fiat currency as backed assets, issuing tokenized fiat pegged stablecoins. These projects build an important bridge between physical value and crypto value. Its characteristic is centralized operation, which requires the issuing institution to be recognized by the industry.
+ The second-generation stablecoin tries to build a decentralized stablecoin from a technical point of view. Starting from bitUSD of project BitShares, which formed a huge category represented by MakerDAO's DAI and QIAN's QUSD after the iterative update. Taking QIAN V1 as an example, in order to obtain a larger circulation and a wider range of underlying assets, crypto assets other than ETH are introduced, such as BUSD and WBTC. However, while the underlying crypto assets expand, some decentralization characteristics are lost. The biggest drawback of the second-generation stablecoin is that the risks of the underlying crypto assets are easily transmitted to the whole stablecoin protocol, thus causing the inherent value fluctuation of the stablecoin. In addition, there are problems such as the low utilization rate of funds caused by over-mortgage.
+ The third-generation stablecoin tries to build original stablecoin of the cryptocurrency industry, represented by the elastic stablecoin AMPL and YAM. These stablecoins do not need to use collateral and are regulated mainly through algorithms. Through the test of the market, elastic stablecoin is insufficient in terms of price stability, and the rebase logic makes it difficult for the smart contract of elastic stablecoin to be combined with other DeFi protocols, which limits the development space of this kind of stablecoin.
+ The latest fifth-generation stablecoin is a fractional-algorithmic stablecoin represented by FRAX. By introducing a partial mortgage mechanism, the stablecoin is easier to launch, and accord with the concept of pure on-chain assets. With volatility lower than pure algorithm stablecoin, this stablecoin type will most likely get extensive applications in the future.

The fractional-algorithmic adjustment mechanism of the fifth-generation stablecoin is the most consistent with the technical evolution goal of Chemix Labs. As the first synthetic asset of Chemix Labs, the technical route which QSD chooses is based on fractional algorithmic.

QSD is a fractional-algorithmic synthetic assets protocol that is open-source, permissionless, and entirely on-chain. The goal of Chemix Labs is to establish a highly scalable, decentralized, algorithmic assets management system, consistently upgrade the technical basis for the development of Chemix Ecosystem.

The technical characteristics of QSD are as follows:

+ **Fractional-Algorithmic**: QSD's supply mechanism is backed by collateral and parts of the supply algorithmic. The range of the collateral/algorithm ratio can fluctuate between 0-100%, and the specific mechanism will depend on the market's pricing of the QSD stablecoin. If QSD is trading at above $1, the protocol decreases the collateral ratio. If QSD is trading at under $1, the protocol increases the collateral ratio. 
+ **Community autonomy**: Chemix Labs protocol will continue to practice the governance principle of community governance. Community developers will develop voluntarily and with no active management.
+ **Fully on-chain oracles**: QSD uses weighted average prices of Uniswap (ETH)，PancakeSwap (Binance Smart Chain) as the oracle source of collateral price, and the target price of $1 is from Chainlink.

### Main tokens
  + **QSD** (QIAN Dollar V2) is the synthetic stablecoin issued by Chemix Labs and target a tight band around $1/coin.The actual price of QSD will fluctuate within a certain range and adjusted by the algorithm;
  + **CEC** (Chemix Ecosystem Coin) is the carrier of seigniorages revenue, algorithm proportion, and governance voting function.
  + **CBT** (CEC buffering token) will be used in the redemption and recollateralization to carry the value released by the algorithm and act as a buffer of CEC price fluctuation;
  + **DBQ** is a special stable bond token, which will serve as a supplementary mechanism for the algorithm to regulate QSD price stability.


### Swap-based Monetary Policy

QSD uses principles from automated market makers like Uniswap to create swap-based price discovery and real-time stabilization incentives through arbitrage.

There are no predetermined timeframes for how quickly the amount of collateralization changes, however, it can be inferred from the partial mortgage mechanism, we believe that as QSD adoption increases, users will be more comfortable with a higher percentage of QSD supply being stabilized algorithmically rather than with collateral. The collateral ratio refresh function in the protocol can be called by any user once per 30 mins at the initial launch. The protocol can change the collateral ratio in steps of 0.2% if the price of QSD is above or below $1. When QSD is above $1, the function lowers the collateral ratio by one step and when the price of QSD is below $1, the function increases the collateral ratio by one step. Both refresh rate and step parameters can be adjusted through governance. 

In order to suppress abnormal price fluctuations, the weighted average result is used to calculate the token price, which can easily lead to a large difference between the target price and the fair market price. Since the protocol's target price is obtained from Chainlink, Chainlink can provide the real market price of USD, which makes QSD has a credible data source for maintaining stability against the USD. It can also avoid malicious manipulation of prices of automatic market makers such as Uniswap and the accompanying distortion.

The QSD is minted with the appropriate amount of collateral and CEC. In the initial phase, the QSD is 99.8% collateral, minting the QSD requires putting in 99.8% collateral and burning 0.2% CEC. The protocol will accept stablecoins as collateral to reduce the risk caused by large fluctuations in the collateral in the initial stage. When the proportion of the algorithm and the issuance of QSD increase, and the system gradually stabilizes, mainstream cryptocurrencies such as BTC, ETH, and BNB will be absorbed as collateral to further expand the coverage of QSD and enhance the robustness of the system.

The name Chemix Labs is derived from "Chemical Reaction X Labs", which means users can synthesize diverse assets as chemists do in our on-chain labs. In the development plan of Chemix Ecosystem, we are seeking for maximum autonomy to create different synthetic assets for our users.
