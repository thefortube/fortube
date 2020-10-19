// SPDX-License-Identifier: MIT

pragma solidity 0.6.4;

interface IInterestRateModel {
    function utilizationRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external pure returns (uint256);

    function getBorrowRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external view returns (uint256);

    function getSupplyRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        uint256 reserveFactorMantissa
    ) external view returns (uint256);

    function APR(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external view returns (uint256);

    function APY(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        uint256 reserveFactorMantissa
    ) external view returns (uint256);
}
