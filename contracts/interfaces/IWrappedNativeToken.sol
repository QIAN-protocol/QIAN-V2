// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

interface IWrappedNativeToken {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}
