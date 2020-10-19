// SPDX-License-Identifier: MIT

pragma solidity 0.6.4;

import "./library/SafeMath.sol";

contract InterestRateModel {
    using SafeMath for uint256;

    uint256 public constant blocksPerYear = 2102400;

    uint256 public multiplierPerBlock;

    uint256 public baseRatePerBlock;

    constructor(uint256 baseRatePerYear, uint256 multiplierPerYear) public {
        baseRatePerBlock = baseRatePerYear.div(blocksPerYear);
        multiplierPerBlock = multiplierPerYear.div(blocksPerYear);
    }

    // 计算利用率
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

    // 借款利率
    function getBorrowRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) public view returns (uint256) {
        uint256 ur = utilizationRate(cash, borrows, reserves);
        return ur.mul(multiplierPerBlock).div(1e18).add(baseRatePerBlock);
    }

    // 存款利率
    function getSupplyRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        uint256 reserveFactorMantissa
    ) public view returns (uint256) {
        uint256 oneMinusReserveFactor = uint256(1e18).sub(
            reserveFactorMantissa
        );
        uint256 borrowRate = getBorrowRate(cash, borrows, reserves);
        uint256 rateToPool = borrowRate.mul(oneMinusReserveFactor).div(1e18);
        return
            utilizationRate(cash, borrows, reserves).mul(rateToPool).div(1e18);
    }

    function APR(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external view returns (uint256) {
        return getBorrowRate(cash, borrows, reserves).mul(blocksPerYear);
    }

    function APY(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        uint256 reserveFactorMantissa
    ) external view returns (uint256) {
        return
            getSupplyRate(cash, borrows, reserves, reserveFactorMantissa).mul(
                blocksPerYear
            );
    }
}
