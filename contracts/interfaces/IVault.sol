// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

interface IVault {
    function globalCollateralRatio() external view returns(uint256);
}
