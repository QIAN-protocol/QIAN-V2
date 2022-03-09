// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

interface IDVM {
    function _BASE_TOKEN_() external view returns(address);
    function _QUOTE_TOKEN_() external view returns(address);
    function _BASE_RESERVE_() external view returns(uint112);
    function _QUOTE_RESERVE_() external view returns(uint112);
    function _BLOCK_TIMESTAMP_LAST_() external view returns(uint32);
    function _BASE_PRICE_CUMULATIVE_LAST_() external view returns(uint256);
    function getVaultReserve() external view returns (uint256 baseReserve, uint256 quoteReserve);
}