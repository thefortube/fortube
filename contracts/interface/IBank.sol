// SPDX-License-Identifier: MIT

pragma solidity 0.6.4;

interface IBank {
    function MonitorEventCallback(bytes32 funcName, bytes calldata payload)
        external;

    function deposit(address token, uint256 amount) external payable;

    function borrow(address token, uint256 amount) external;

    function withdraw(address underlying, uint256 withdrawTokens) external;

    function withdrawUnderlying(address underlying, uint256 amount) external;

    function repay(address token, uint256 amount) external payable;

    function liquidateBorrow(
        address borrower,
        address underlyingBorrow,
        address underlyingCollateral,
        uint256 repayAmount
    ) external payable;

    function tokenIn(address token, uint256 amountIn) external payable;

    function tokenOut(address token, uint256 amountOut) external;

    function cancellingOut(address token) external;

    function paused() external view returns (bool);
}