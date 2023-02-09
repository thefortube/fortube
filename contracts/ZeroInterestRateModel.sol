// SPDX-License-Identifier: MIT

pragma solidity 0.6.4;

import "./library/SafeMath.sol";

contract ZeroInterestRateModel {
    using SafeMath for uint256;

    function utilizationRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) public pure returns (uint256) {
        if (borrows == 0) {
            return 0;
        }

        // borrows/(cash + borrows)
        return borrows.mul(1e18).div(cash.add(borrows));
    }

    function getBorrowRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) public view returns (uint256) {
        return 0;
    }

    function getSupplyRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        uint256 reserveFactorMantissa
    ) public view returns (uint256) {
        return 0;
    }

    function APR(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external view returns (uint256) {
        return 0;
    }

    function APY(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        uint256 reserveFactorMantissa
    ) external view returns (uint256) {
        return 0;
    }
}
