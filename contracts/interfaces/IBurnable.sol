// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

interface IBurnable {
    function burnFrom(address account, uint256 amount) external;
}
