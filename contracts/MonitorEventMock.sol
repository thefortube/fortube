// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity 0.6.4;

contract MonitorEventMock {
    event Deposit(
        address user_address,
        address token_address,
        address cheque_token_address,
        uint256 amount_deposited,
        uint256 underlying_deposited,
        uint256 cheque_token_value,
        uint256 loan_interest_rate,
        uint256 account_balance,
        uint256 global_token_reserved
    );

    event Borrow(
        address user_address,
        address token_address,
        address cheque_token_address,
        uint256 amount_borrowed,
        uint256 interest_accrued,
        uint256 cheque_token_value,
        uint256 loan_interest_rate,
        uint256 account_debt,
        uint256 global_token_reserved
    );

    event Repay(
        address user_address,
        address token_address,
        address cheque_token_address,
        uint256 amount_repayed,
        uint256 interest_accrued,
        uint256 cheque_token_value,
        uint256 loan_interest_rate,
        uint256 account_debt,
        uint256 global_token_reserved
    );

    event Withdraw(
        address user_address,
        address token_address,
        address cheque_token_address,
        uint256 amount_withdrawed,
        uint256 underlying_withdrawed,
        uint256 cheque_token_value,
        uint256 loan_interest_rate,
        uint256 account_balance,
        uint256 global_token_reserved
    );

    event WithdrawUnderlying(
        address user_address,
        address token_address,
        address cheque_token_address,
        uint256 amount_withdrawed,
        uint256 underlying_withdrawed,
        uint256 cheque_token_value,
        uint256 loan_interest_rate,
        uint256 account_balance,
        uint256 global_token_reserved
    );

    event Transfer(
        address user_address,
        address token_address,
        address cheque_token_address,
        uint256 amount_transferred,
        uint256 account_balance,
        address payee_address,
        uint256 payee_balance,
        uint256 global_token_reserved
    );

    event TransferFrom(
        address user_address,
        address token_address,
        address cheque_token_address,
        uint256 amount_transferred,
        uint256 account_balance,
        address payee_address,
        uint256 payee_balance,
        uint256 global_token_reserved
    );

    event LiquidateBorrow(
        address user_address,
        address token_address,
        address cheque_token_address,
        uint256 debt_written_off,
        uint256 interest_accrued,
        address debtor_address,
        uint256 collateral_purchased,
        address collateral_cheque_token_address,
        uint256 debtor_balance,
        uint256 debt_remaining,
        uint256 cheque_token_value,
        uint256 loan_interest_rate,
        uint256 account_balance,
        uint256 global_token_reserved
    );

    event CancellingOut(
        address user_address,
        address token_address,
        address cheque_token_address,
        uint256 amount_wiped_out,
        uint256 debt_cancelled_out,
        uint256 interest_accrued,
        uint256 cheque_token_value,
        uint256 loan_interest_rate,
        uint256 account_balance,
        uint256 account_debt,
        uint256 global_token_reserved
    );

    event TokenIn(
        address token,
        uint256 amountIn
    );

    event TokenOut(
        address token,
        uint256 amountOut
    );

    event ReserveDeposit(
        address token_address,
        uint256 reserve_funded,
        uint256 cheque_token_value,
        uint256 loan_interest_rate,
        uint256 global_token_reserved
    );

    event ReserveWithdrawal(
        address token_address,
        uint256 reserve_withdrawed,
        uint256 cheque_token_value,
        uint256 loan_interest_rate,
        uint256 global_token_reserved
    );
}
