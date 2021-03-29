// SPDX-License-Identifier: MIT

pragma solidity 0.6.4;

enum RewardType {
    DefaultType,
    Deposit,
    Borrow,
    Withdraw,
    Repay,
    Liquidation,
    TokenIn,
    TokenOut
}
