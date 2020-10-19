// SPDX-License-Identifier: MIT

pragma solidity 0.6.4;

enum RewardType {
    DefaultType,
    Deposit,
    Borrow,
    Withdraw,
    Repay,
    Liquidation,
    TokenIn, //入金，为还款和存款的组合
    TokenOut //出金， 为取款和借款的组合
}