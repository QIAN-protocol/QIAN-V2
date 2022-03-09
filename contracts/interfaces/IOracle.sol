// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

interface IOracle {
    function getLatestPrice() external view returns (uint256);
}
