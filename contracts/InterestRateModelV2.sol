// SPDX-License-Identifier: MIT

pragma solidity 0.6.4;

import "./library/SafeMath.sol";

import "@openzeppelin/upgrades/contracts/Initializable.sol";

contract InterestRateModelV2 is Initializable {
    using SafeMath for uint256;
    uint256 public multiplierPerBlock;
    uint256 public jumpMultiplierPerBlock;
    uint256 public jumpPoint;

    uint256 public baseRatePerBlock;

    uint256 public blocksPerYear;//ETH: 2102400, BSC: 10512000

    address public admin;

    function initialize(
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 jumpMultiplierPerYear,
        uint256 _blocksPerYear,
        uint256 _jumpPoint
    ) public initializer {
        blocksPerYear = _blocksPerYear;
        baseRatePerBlock = baseRatePerYear.div(blocksPerYear);
        multiplierPerBlock = multiplierPerYear.div(blocksPerYear);
        jumpMultiplierPerBlock = jumpMultiplierPerYear.div(blocksPerYear);
        jumpPoint = _jumpPoint;

        admin = msg.sender;
    }

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
        uint256 ur = utilizationRate(cash, borrows, reserves);
        if (ur <= jumpPoint) {
            return ur.mul(multiplierPerBlock).div(1e18).add(baseRatePerBlock);
        } else {
            uint256 jumpPointRate = jumpPoint.mul(multiplierPerBlock).div(1e18).add(baseRatePerBlock);
            uint256 excessUr = ur.sub(jumpPoint);
            return excessUr.mul(jumpMultiplierPerBlock).div(1e18).add(jumpPointRate);
        }
    }

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
