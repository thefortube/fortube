// SPDX-License-Identifier: MIT

pragma solidity 0.6.4;

interface IBankController {
    function getCashPrior(address underlying) external view returns (uint256);

    function getCashAfter(address underlying, uint256 msgValue)
        external
        view
        returns (uint256);

    function getFTokeAddress(address underlying)
        external
        view
        returns (address);

    function transferToUser(
        address token,
        address payable user,
        uint256 amount
    ) external;

    function transferIn(
        address account,
        address underlying,
        uint256 amount
    ) external payable;

    function borrowCheck(
        address account,
        address underlying,
        address fToken,
        uint256 borrowAmount
    ) external;

    function repayCheck(address underlying) external;

    function liquidateBorrowCheck(
        address fTokenBorrowed,
        address fTokenCollateral,
        address borrower,
        address liquidator,
        uint256 repayAmount
    ) external;

    function liquidateTokens(
        address fTokenBorrowed,
        address fTokenCollateral,
        uint256 actualRepayAmount
    ) external view returns (uint256);

    function withdrawCheck(
        address fToken,
        address withdrawer,
        uint256 withdrawTokens
    ) external view returns (uint256);

    function transferCheck(
        address fToken,
        address src,
        address dst,
        uint256 transferTokens
    ) external;

    function marketsContains(address fToken) external view returns (bool);

    function seizeCheck(address cTokenCollateral, address cTokenBorrowed)
        external;

    function mintCheck(address underlying, address minter, uint256 amount) external;

    function addReserves(address underlying, uint256 addAmount)
        external
        payable;

    function reduceReserves(
        address underlying,
        address payable account,
        uint256 reduceAmount
    ) external;

    function calcMaxBorrowAmount(address user, address token)
        external
        view
        returns (uint256);

    function calcMaxWithdrawAmount(address user, address token)
        external
        view
        returns (uint256);

    function calcMaxCashOutAmount(address user, address token)
        external
        view
        returns (uint256);

    function calcMaxBorrowAmountWithRatio(address user, address token)
        external
        view
        returns (uint256);

    function transferEthGasCost() external view returns (uint256);

    function isFTokenValid(address fToken) external view returns (bool);

    function balance(address token) external view returns (uint256);
    function flashloanFeeBips() external view returns (uint256);
    function flashloanVault() external view returns (address);
    function transferFlashloanAsset(
        address token,
        address payable user,
        uint256 amount
    ) external;
}
