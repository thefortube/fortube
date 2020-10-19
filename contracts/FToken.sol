// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity 0.6.4;

import "./interface/IInterestRateModel.sol";
import "./interface/IBankController.sol";
import "./Exponential.sol";
import "./library/SafeERC20.sol";
import "./library/EthAddressLib.sol";
import "./interface/IERC20.sol";
import "./interface/IFToken.sol";
import "./interface/IBank.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";

contract FToken is Exponential, Initializable {
    using SafeERC20 for IERC20;

    uint256 public totalSupply;

    string public name;

    string public symbol;

    uint8 public decimals;

    mapping(address => mapping(address => uint256)) internal transferAllowances;

    uint256 public initialExchangeRate;

    address public admin;

    uint256 public totalBorrows;

    uint256 public totalReserves;

    uint256 public reserveFactor;

    uint256 public borrowIndex;

    uint256 internal constant borrowRateMax = 0.0005e16;

    uint256 public accrualBlockNumber;

    IInterestRateModel public interestRateModel;

    // 该 fToken 所代表的原生代币
    address public underlying;

    mapping(address => uint256) public accountTokens;

    IBankController public controller;

    uint256 public borrowSafeRatio;

    address public bank; // bank主合约入口地址

    bool internal _notEntered;

    uint256 public constant ONE = 1e18;

    // 借款人账户
    struct BorrowSnapshot {
        uint256 principal;
        uint256 interestIndex;
    }

    mapping(address => BorrowSnapshot) public accountBorrows;
    uint256 public totalCash;

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function initialize(
        uint256 _initialExchangeRate,
        address _controller,
        address _initialInterestRateModel,
        address _underlying,
        address _bank,
        uint256 _borrowSafeRatio,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) public initializer {
        initialExchangeRate = _initialExchangeRate;
        controller = IBankController(_controller);
        interestRateModel = IInterestRateModel(_initialInterestRateModel);
        admin = msg.sender;
        underlying = _underlying;
        borrowSafeRatio = _borrowSafeRatio;
        accrualBlockNumber = getBlockNumber();
        borrowIndex = ONE;
        bank = _bank;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        _notEntered = true;
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "require admin");
        _;
    }

    modifier onlyBank {
        require(msg.sender == bank, "require admin");
        _;
    }

    modifier onlyController {
        require(msg.sender == address(controller), "require controller");
        _;
    }

    modifier onlyRestricted {
        require(
            msg.sender == admin ||
                msg.sender == bank ||
                msg.sender == address(controller) ||
                controller.marketsContains(msg.sender),
            "only restricted user"
        );
        _;
    }

    modifier onlyBankComponent {
        require(
            msg.sender == bank ||
                msg.sender == address(controller) ||
                msg.sender == address(this) ||
                controller.marketsContains(msg.sender),
            "only bank component"
        );
        _;
    }

    modifier whenUnpaused {
        require(!IBank(bank).paused(), "System paused");
        _;
    }

    function _setController(address _controller) external onlyAdmin {
        controller = IBankController(_controller);
    }

    function tokenCash(address token, address account)
        public
        view
        returns (uint256)
    {
        return
            token != EthAddressLib.ethAddress()
                ? IERC20(token).balanceOf(account)
                : address(account).balance;
    }

    struct TransferLogStruct {
        address user_address;
        address token_address;
        address cheque_token_address;
        uint256 amount_transferred;
        uint256 account_balance;
        address payee_address;
        uint256 payee_balance;
        uint256 global_token_reserved;
    }

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     */
    function transfer(address dst, uint256 amount)
        external
        nonReentrant
        returns (bool)
    {
        // spender - src - dst
        transferTokens(msg.sender, msg.sender, dst, amount);

        TransferLogStruct memory tls = TransferLogStruct(
            msg.sender,
            underlying,
            address(this),
            amount,
            balanceOf(msg.sender),
            dst,
            balanceOf(dst),
            tokenCash(underlying, address(controller))
        );

        IBank(bank).MonitorEventCallback("Transfer", abi.encode(tls));

        return true;
    }

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     */
    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external nonReentrant returns (bool) {
        // spender - src - dst
        transferTokens(msg.sender, src, dst, amount);

        TransferLogStruct memory tls = TransferLogStruct(
            msg.sender,
            underlying,
            address(this),
            amount,
            balanceOf(msg.sender),
            dst,
            balanceOf(dst),
            tokenCash(underlying, address(controller))
        );

        IBank(bank).MonitorEventCallback("TransferFrom", abi.encode(tls));

        return true;
    }

    // tokens -> 转账的 fToken 的数量
    function transferTokens(
        address spender,
        address src,
        address dst,
        uint256 tokens
    ) internal whenUnpaused returns (bool) {
        //accrueInterest();
        controller.transferCheck(address(this), src, dst, mulScalarTruncate(tokens, borrowSafeRatio));

        require(src != dst, "Cannot transfer to self");

        uint256 startingAllowance = 0;
        if (spender == src) {
            startingAllowance = uint256(-1);
        } else {
            startingAllowance = transferAllowances[src][spender];
        }

        uint256 allowanceNew = startingAllowance.sub(tokens);

        accountTokens[src] = accountTokens[src].sub(tokens);
        accountTokens[dst] = accountTokens[dst].add(tokens);

        if (startingAllowance != uint256(-1)) {
            transferAllowances[src][spender] = allowanceNew;
        }

        emit Transfer(src, dst, tokens);
        return true;
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param amount The number of tokens that are approved (-1 means infinite)
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        address src = msg.sender;
        transferAllowances[src][spender] = amount;
        emit Approval(src, spender, amount);
        return true;
    }

    /**
     * @notice Get the current allowance from `owner` for `spender`
     * @param owner The address of the account which owns the tokens to be spent
     * @param spender The address of the account which may transfer tokens
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256)
    {
        return transferAllowances[owner][spender];
    }

    struct MintLocals {
        uint256 exchangeRate;
        uint256 mintTokens;
        uint256 totalSupplyNew;
        uint256 accountTokensNew;
        uint256 actualMintAmount;
    }

    struct DepositLogStruct {
        address user_address;
        address token_address;
        address cheque_token_address;
        uint256 amount_deposited;
        uint256 underlying_deposited;
        uint256 cheque_token_value;
        uint256 loan_interest_rate;
        uint256 account_balance;
        uint256 global_token_reserved;
    }

    // 存款记账
    function mint(address user, uint256 amount)
        external
        onlyBank
        nonReentrant
        returns (bytes memory)
    {
        accrueInterest();
        return mintInternal(user, amount);
    }

    // 存款记账
    function mintInternal(address user, uint256 amount)
        internal
        returns (bytes memory)
    {
        require(accrualBlockNumber == getBlockNumber(), "Blocknumber fails");
        MintLocals memory tmp;
        controller.mintCheck(underlying, user);
        tmp.exchangeRate = exchangeRateStored();
        tmp.mintTokens = divScalarByExpTruncate(amount, tmp.exchangeRate);
        tmp.totalSupplyNew = addExp(totalSupply, tmp.mintTokens);
        tmp.accountTokensNew = addExp(accountTokens[user], tmp.mintTokens);
        totalSupply = tmp.totalSupplyNew;
        accountTokens[user] = tmp.accountTokensNew;

        uint256 preCalcTokenCash = tokenCash(underlying, address(controller))
            .add(amount);

        DepositLogStruct memory dls = DepositLogStruct(
            user,
            underlying,
            address(this),
            tmp.mintTokens,
            amount,
            exchangeRateAfter(amount), //cheque_token_value, 存之后的交换率（预判）
            interestRateModel.getBorrowRate(
                preCalcTokenCash,
                totalBorrows,
                totalReserves
            ), //loan_interest_rate 借款利率,存之后的价款利率
            tokenCash(address(this), user),
            preCalcTokenCash
        );

        emit Transfer(address(0), user, tmp.mintTokens);

        return abi.encode(dls);
    }

    struct BorrowLocals {
        uint256 accountBorrows;
        uint256 accountBorrowsNew;
        uint256 totalBorrowsNew;
    }

    struct BorrowLogStruct {
        address user_address;
        address token_address;
        address cheque_token_address;
        uint256 amount_borrowed;
        uint256 interest_accrued;
        uint256 cheque_token_value;
        uint256 loan_interest_rate;
        uint256 account_debt;
        uint256 global_token_reserved;
    }

    // 用户借钱
    function borrow(address payable borrower, uint256 borrowAmount)
        external
        onlyBank
        nonReentrant
        returns (bytes memory)
    {
        accrueInterest();
        return borrowInternal(borrower, borrowAmount);
    }

    // 用户借钱
    function borrowInternal(address payable borrower, uint256 borrowAmount)
        internal
        returns (bytes memory)
    {
        controller.borrowCheck(
            borrower,
            underlying,
            address(this),
            mulScalarTruncate(borrowAmount, borrowSafeRatio)
        );

        require(
            controller.getCashPrior(underlying) >= borrowAmount,
            "Insufficient balance"
        );

        BorrowLocals memory tmp;
        uint256 lastPrincipal = accountBorrows[borrower].principal;
        tmp.accountBorrows = borrowBalanceStoredInternal(borrower);
        tmp.accountBorrowsNew = addExp(tmp.accountBorrows, borrowAmount);
        tmp.totalBorrowsNew = addExp(totalBorrows, borrowAmount);

        accountBorrows[borrower].principal = tmp.accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = tmp.totalBorrowsNew;

        controller.transferToUser(underlying, borrower, borrowAmount);
        subTotalCash(borrowAmount);

        BorrowLogStruct memory bls = BorrowLogStruct(
            borrower,
            underlying,
            address(this),
            borrowAmount,
            SafeMath.abs(tmp.accountBorrows, lastPrincipal),
            exchangeRateStored(),
            getBorrowRate(),
            accountBorrows[borrower].principal,
            tokenCash(underlying, address(controller))
        );

        return abi.encode(bls);
    }

    struct RepayLocals {
        uint256 repayAmount;
        uint256 borrowerIndex;
        uint256 accountBorrows;
        uint256 accountBorrowsNew;
        uint256 totalBorrowsNew;
        uint256 actualRepayAmount;
    }

    // 计算兑换率
    function exchangeRateStored() public view returns (uint256 exchangeRate) {
        return calcExchangeRate(totalBorrows, totalReserves);
    }

    function calcExchangeRate(uint256 _totalBorrows, uint256 _totalReserves)
        public
        view
        returns (uint256 exchangeRate)
    {
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            return initialExchangeRate;
        } else {
            /*
             *  exchangeRate = (totalCash + totalBorrows - totalReserves) / totalSupply
             */
            uint256 totalCash = controller.getCashPrior(underlying);
            uint256 cashPlusBorrowsMinusReserves = subExp(
                addExp(totalCash, _totalBorrows),
                _totalReserves
            );
            exchangeRate = getDiv(cashPlusBorrowsMinusReserves, _totalSupply);
        }
    }

    // 计算兑换率(预判)，在实际转账之前调用，只是用于发事件，用户后端审计
    function exchangeRateAfter(uint256 transferInAmout)
        public
        view
        returns (uint256 exchangeRate)
    {
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            // 如果市场是初始化状态，那么返回初始兑换率
            return initialExchangeRate;
        } else {
            /*
             *  exchangeRate = (totalCash + totalBorrows - totalReserves) / totalSupply
             */
            uint256 totalCash = controller.getCashAfter(
                underlying,
                transferInAmout
            );
            uint256 cashPlusBorrowsMinusReserves = subExp(
                addExp(totalCash, totalBorrows),
                totalReserves
            );
            exchangeRate = getDiv(cashPlusBorrowsMinusReserves, _totalSupply);
        }
    }

    function balanceOfUnderlying(address owner) external returns (uint256) {
        // 获取利率
        uint256 exchangeRate = exchangeRateCurrent();
        // 利率乘余额
        uint256 balance = mulScalarTruncate(exchangeRate, accountTokens[owner]);
        return balance;
    }

    function calcBalanceOfUnderlying(address owner)
        public
        view
        returns (uint256)
    {
        (, , uint256 _totalBorrows, uint256 _trotalReserves) = peekInterest();

        uint256 _exchangeRate = calcExchangeRate(
            _totalBorrows,
            _trotalReserves
        );
        // 利率乘余额
        uint256 balance = mulScalarTruncate(
            _exchangeRate,
            accountTokens[owner]
        );
        return balance;
    }

    function exchangeRateCurrent() public nonReentrant returns (uint256) {
        accrueInterest();
        return exchangeRateStored();
    }

    // 获取账户信息
    function getAccountState(address account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 fTokenBalance = accountTokens[account];
        uint256 borrowBalance = borrowBalanceStoredInternal(account);
        uint256 exchangeRate = exchangeRateStored();

        return (fTokenBalance, borrowBalance, exchangeRate);
    }

    struct WithdrawLocals {
        uint256 exchangeRate;
        uint256 withdrawTokens;
        uint256 withdrawAmount;
        uint256 totalSupplyNew;
        uint256 accountTokensNew;
    }

    struct WithdrawLogStruct {
        address user_address;
        address token_address;
        address cheque_token_address;
        uint256 amount_withdrawed;
        uint256 underlying_withdrawed;
        uint256 cheque_token_value;
        uint256 loan_interest_rate;
        uint256 account_balance;
        uint256 global_token_reserved;
    }

    // todo onlyController
    function withdraw(
        address payable withdrawer,
        uint256 withdrawTokensIn,
        uint256 withdrawAmountIn
    ) external onlyBank nonReentrant returns (uint256, bytes memory) {
        accrueInterest();
        return withdrawInternal(withdrawer, withdrawTokensIn, withdrawAmountIn);
    }

    function withdrawInternal(
        address payable withdrawer,
        uint256 withdrawTokensIn,
        uint256 withdrawAmountIn
    ) internal returns (uint256, bytes memory) {
        // 一个是想要兑换 cTokens 的数量，一个是想要兑换 asset 的数量，必须有一个是 0
        require(
            withdrawTokensIn == 0 || withdrawAmountIn == 0,
            "withdraw parameter not valid"
        );
        WithdrawLocals memory tmp;

        tmp.exchangeRate = exchangeRateStored();

        if (withdrawTokensIn > 0) {
            tmp.withdrawTokens = withdrawTokensIn;
            tmp.withdrawAmount = mulScalarTruncate(
                tmp.exchangeRate,
                withdrawTokensIn
            );
        } else {
            tmp.withdrawTokens = divScalarByExpTruncate(
                withdrawAmountIn,
                tmp.exchangeRate
            );
            tmp.withdrawAmount = withdrawAmountIn;
        }

        controller.withdrawCheck(address(this), withdrawer, tmp.withdrawTokens);

        require(accrualBlockNumber == getBlockNumber(), "Blocknumber fails");

        tmp.totalSupplyNew = totalSupply.sub(tmp.withdrawTokens);
        tmp.accountTokensNew = accountTokens[withdrawer].sub(
            tmp.withdrawTokens
        );

        require(
            controller.getCashPrior(underlying) >= tmp.withdrawAmount,
            "Insufficient money"
        );

        controller.transferToUser(underlying, withdrawer, tmp.withdrawAmount);
        subTotalCash(tmp.withdrawAmount);

        totalSupply = tmp.totalSupplyNew;
        accountTokens[withdrawer] = tmp.accountTokensNew;

        WithdrawLogStruct memory wls = WithdrawLogStruct(
            withdrawer,
            underlying,
            address(this),
            tmp.withdrawTokens,
            tmp.withdrawAmount,
            exchangeRateStored(),
            getBorrowRate(),
            tokenCash(address(this), withdrawer),
            tokenCash(underlying, address(controller))
        );

        emit Transfer(withdrawer, address(0), tmp.withdrawTokens);

        return (tmp.withdrawAmount, abi.encode(wls));
    }

    function strikeWithdrawInternal(
        address withdrawer,
        uint256 withdrawTokensIn,
        uint256 withdrawAmountIn
    ) internal returns (uint256, bytes memory) {
        // 一个是想要兑换 cTokens 的数量，一个是想要兑换 asset 的数量，必须有一个是 0
        require(
            withdrawTokensIn == 0 || withdrawAmountIn == 0,
            "withdraw parameter not valid"
        );
        WithdrawLocals memory tmp;

        tmp.exchangeRate = exchangeRateStored();

        if (withdrawTokensIn > 0) {
            tmp.withdrawTokens = withdrawTokensIn;
            tmp.withdrawAmount = mulScalarTruncate(
                tmp.exchangeRate,
                withdrawTokensIn
            );
        } else {
            tmp.withdrawTokens = divScalarByExpTruncate(
                withdrawAmountIn,
                tmp.exchangeRate
            );
            tmp.withdrawAmount = withdrawAmountIn;
        }

        require(accrualBlockNumber == getBlockNumber(), "Blocknumber fails");

        tmp.totalSupplyNew = totalSupply.sub(tmp.withdrawTokens);
        tmp.accountTokensNew = accountTokens[withdrawer].sub(
            tmp.withdrawTokens
        );

        totalSupply = tmp.totalSupplyNew;
        accountTokens[withdrawer] = tmp.accountTokensNew;

        uint256 preCalcTokenCash = tokenCash(underlying, address(controller))
            .add(tmp.withdrawAmount);

        WithdrawLogStruct memory wls = WithdrawLogStruct(
            withdrawer,
            underlying,
            address(this),
            tmp.withdrawTokens,
            tmp.withdrawAmount,
            exchangeRateStored(),
            interestRateModel.getBorrowRate(
                preCalcTokenCash,
                totalBorrows,
                totalReserves
            ),
            tokenCash(address(this), withdrawer),
            preCalcTokenCash
        );

        emit Transfer(withdrawer, address(0), tmp.withdrawTokens);

        return (tmp.withdrawAmount, abi.encode(wls));
    }

    // 更新利息
    function accrueInterest() public onlyRestricted {
        uint256 currentBlockNumber = getBlockNumber();
        uint256 accrualBlockNumberPrior = accrualBlockNumber;

        // 太短 零利息
        if (accrualBlockNumberPrior == currentBlockNumber) {
            return;
        }

        uint256 cashPrior = controller.getCashPrior(underlying);
        uint256 borrowsPrior = totalBorrows;
        uint256 reservesPrior = totalReserves;
        uint256 borrowIndexPrior = borrowIndex;

        // // 计算借贷利率
        uint256 borrowRate = interestRateModel.getBorrowRate(
            cashPrior,
            borrowsPrior,
            reservesPrior
        );
        // // 不能超过最大利率
        require(borrowRate <= borrowRateMax, "borrow rate is too high");

        // // 计算块差
        uint256 blockDelta = currentBlockNumber.sub(accrualBlockNumberPrior);

        /*
         *  simpleInterestFactor = borrowRate * blockDelta
         *  interestAccumulated = simpleInterestFactor * totalBorrows
         *  totalBorrowsNew = interestAccumulated + totalBorrows
         *  totalReservesNew = interestAccumulated * reserveFactor + totalReserves
         *  borrowIndexNew = simpleInterestFactor * borrowIndex + borrowIndex
         */

        uint256 simpleInterestFactor;
        uint256 interestAccumulated;
        uint256 totalBorrowsNew;
        uint256 totalReservesNew;
        uint256 borrowIndexNew;

        simpleInterestFactor = mulScalar(borrowRate, blockDelta);

        interestAccumulated = divExp(
            mulExp(simpleInterestFactor, borrowsPrior),
            expScale
        );

        totalBorrowsNew = addExp(interestAccumulated, borrowsPrior);

        totalReservesNew = addExp(
            divExp(mulExp(reserveFactor, interestAccumulated), expScale),
            reservesPrior
        );

        borrowIndexNew = addExp(
            divExp(mulExp(simpleInterestFactor, borrowIndexPrior), expScale),
            borrowIndexPrior
        );

        accrualBlockNumber = currentBlockNumber;
        borrowIndex = borrowIndexNew;
        totalBorrows = totalBorrowsNew;
        totalReserves = totalReservesNew;

        borrowRate = interestRateModel.getBorrowRate(
            cashPrior,
            totalBorrows,
            totalReserves
        );
        // 不能超过最大利率
        require(borrowRate <= borrowRateMax, "borrow rate is too high");
    }

    function peekInterest()
        public
        view
        returns (
            uint256 _accrualBlockNumber,
            uint256 _borrowIndex,
            uint256 _totalBorrows,
            uint256 _totalReserves
        )
    {
        _accrualBlockNumber = getBlockNumber();
        uint256 accrualBlockNumberPrior = accrualBlockNumber;

        // 太短 零利息
        if (accrualBlockNumberPrior == _accrualBlockNumber) {
            return (
                accrualBlockNumber,
                borrowIndex,
                totalBorrows,
                totalReserves
            );
        }

        uint256 cashPrior = controller.getCashPrior(underlying);
        uint256 borrowsPrior = totalBorrows;
        uint256 reservesPrior = totalReserves;
        uint256 borrowIndexPrior = borrowIndex;

        // // 计算借贷利率
        uint256 borrowRate = interestRateModel.getBorrowRate(
            cashPrior,
            borrowsPrior,
            reservesPrior
        );
        // // 不能超过最大利率
        require(borrowRate <= borrowRateMax, "borrow rate is too high");

        // // 计算块差
        uint256 blockDelta = _accrualBlockNumber.sub(accrualBlockNumberPrior);

        /*
         *  simpleInterestFactor = borrowRate * blockDelta
         *  interestAccumulated = simpleInterestFactor * totalBorrows
         *  totalBorrowsNew = interestAccumulated + totalBorrows
         *  totalReservesNew = interestAccumulated * reserveFactor + totalReserves
         *  borrowIndexNew = simpleInterestFactor * borrowIndex + borrowIndex
         */

        uint256 simpleInterestFactor;
        uint256 interestAccumulated;
        uint256 totalBorrowsNew;
        uint256 totalReservesNew;
        uint256 borrowIndexNew;

        simpleInterestFactor = mulScalar(borrowRate, blockDelta);

        interestAccumulated = divExp(
            mulExp(simpleInterestFactor, borrowsPrior),
            expScale
        );

        totalBorrowsNew = addExp(interestAccumulated, borrowsPrior);

        totalReservesNew = addExp(
            divExp(mulExp(reserveFactor, interestAccumulated), expScale),
            reservesPrior
        );

        borrowIndexNew = addExp(
            divExp(mulExp(simpleInterestFactor, borrowIndexPrior), expScale),
            borrowIndexPrior
        );

        _borrowIndex = borrowIndexNew;
        _totalBorrows = totalBorrowsNew;
        _totalReserves = totalReservesNew;

        borrowRate = interestRateModel.getBorrowRate(
            cashPrior,
            totalBorrows,
            totalReserves
        );
        // 不能超过最大利率
        require(borrowRate <= borrowRateMax, "borrow rate is too high");
    }

    function borrowBalanceCurrent(address account)
        external
        nonReentrant
        returns (uint256)
    {
        accrueInterest();
        BorrowSnapshot memory borrowSnapshot = accountBorrows[account];
        require(borrowSnapshot.interestIndex <= borrowIndex, "borrowIndex error");

        return borrowBalanceStoredInternal(account);
    }

    function borrowBalanceStoredInternal(address user)
        internal
        view
        returns (uint256 result)
    {
        // 借贷数量
        BorrowSnapshot memory borrowSnapshot = accountBorrows[user];

        if (borrowSnapshot.principal == 0) {
            return 0;
        }

        result = mulExp(borrowSnapshot.principal, divExp(borrowIndex, borrowSnapshot.interestIndex));
    }

    function _setReserveFactorFresh(uint256 newReserveFactor)
        external
        onlyAdmin
        nonReentrant
    {
        accrueInterest();
        require(accrualBlockNumber == getBlockNumber(), "Blocknumber fails");
        reserveFactor = newReserveFactor;
    }

    function _setInterestRateModel(IInterestRateModel newInterestRateModel)
        external
        onlyAdmin
    {
        accrueInterest();
        require(accrualBlockNumber == getBlockNumber(), "Blocknumber fails");
        interestRateModel = newInterestRateModel;
    }

    function getBlockNumber() internal view returns (uint256) {
        return block.number;
    }

    function repay(address borrower, uint256 repayAmount)
        external
        onlyBank
        nonReentrant
        returns (uint256, bytes memory)
    {
        accrueInterest();
        return repayInternal(borrower, repayAmount);
    }

    struct RepayLogStruct {
        address user_address;
        address token_address;
        address cheque_token_address;
        uint256 amount_repayed;
        uint256 interest_accrued;
        uint256 cheque_token_value;
        uint256 loan_interest_rate;
        uint256 account_debt;
        uint256 global_token_reserved;
    }

    function repayInternal(address borrower, uint256 repayAmount)
        internal
        returns (uint256, bytes memory)
    {
        controller.repayCheck(underlying);
        require(accrualBlockNumber == getBlockNumber(), "Blocknumber fails");

        RepayLocals memory tmp;
        uint256 lastPrincipal = accountBorrows[borrower].principal;
        tmp.borrowerIndex = accountBorrows[borrower].interestIndex;
        tmp.accountBorrows = borrowBalanceStoredInternal(borrower);

        // -1 表示还最大
        if (repayAmount == uint256(-1)) {
            tmp.repayAmount = tmp.accountBorrows;
        } else {
            tmp.repayAmount = repayAmount;
        }

        tmp.accountBorrowsNew = tmp.accountBorrows.sub(tmp.repayAmount);
        if (totalBorrows < tmp.repayAmount) {
            tmp.totalBorrowsNew = 0;
        } else {
            tmp.totalBorrowsNew = totalBorrows.sub(tmp.repayAmount);
        }

        accountBorrows[borrower].principal = tmp.accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = tmp.totalBorrowsNew;

        uint256 preCalcTokenCash = tokenCash(underlying, address(controller))
            .add(tmp.repayAmount);

        RepayLogStruct memory rls = RepayLogStruct(
            borrower,
            underlying,
            address(this),
            tmp.repayAmount,
            SafeMath.abs(tmp.accountBorrows, lastPrincipal),
            exchangeRateAfter(tmp.repayAmount), //repay之后的交换率
            interestRateModel.getBorrowRate(
                preCalcTokenCash,
                totalBorrows,
                totalReserves
            ), //repay之后的借款利率
            accountBorrows[borrower].principal,
            preCalcTokenCash
        );

        return (tmp.repayAmount, abi.encode(rls));
    }

    function borrowBalanceStored(address account)
        external
        view
        returns (uint256)
    {
        return borrowBalanceStoredInternal(account);
    }

    struct LiquidateBorrowLogStruct {
        address user_address;
        address token_address;
        address cheque_token_address;
        uint256 debt_written_off;
        uint256 interest_accrued;
        address debtor_address;
        uint256 collateral_purchased;
        address collateral_cheque_token_address;
        uint256 debtor_balance;
        uint256 debt_remaining;
        uint256 cheque_token_value;
        uint256 loan_interest_rate;
        uint256 account_balance;
        uint256 global_token_reserved;
    }

    function liquidateBorrow(
        address liquidator,
        address borrower,
        uint256 repayAmount,
        FToken fTokenCollateral
    ) public onlyBank nonReentrant returns (bytes memory) {
        require(
            controller.isFTokenValid(address(this)) &&
                controller.isFTokenValid(address(fTokenCollateral)),
            "Market not listed"
        );
        accrueInterest();
        fTokenCollateral.accrueInterest();
        uint256 lastPrincipal = accountBorrows[borrower].principal;
        uint256 newPrincipal = borrowBalanceStoredInternal(borrower);

        controller.liquidateBorrowCheck(
            address(this),
            address(fTokenCollateral),
            borrower,
            liquidator,
            repayAmount
        );

        require(accrualBlockNumber == getBlockNumber(), "Blocknumber fails");
        require(
            fTokenCollateral.accrualBlockNumber() == getBlockNumber(),
            "Blocknumber fails"
        );

        // 还钱
        (uint256 actualRepayAmount, ) = repayInternal(borrower, repayAmount);

        // 计算清算的质押物数量（fToken数量）
        uint256 seizeTokens = controller.liquidateTokens(
            address(this),
            address(fTokenCollateral),
            actualRepayAmount
        );

        // 借款人得要有这么多余额才行
        require(
            fTokenCollateral.balanceOf(borrower) >= seizeTokens,
            "Seize too much"
        );

        if (address(fTokenCollateral) == address(this)) {
            seizeInternal(address(this), liquidator, borrower, seizeTokens);
        } else {
            fTokenCollateral.seize(liquidator, borrower, seizeTokens);
        }

        uint256 preCalcTokenCash = tokenCash(underlying, address(controller))
            .add(actualRepayAmount);

        LiquidateBorrowLogStruct memory lbls = LiquidateBorrowLogStruct(
            liquidator,
            underlying,
            address(this),
            actualRepayAmount,
            SafeMath.abs(newPrincipal, lastPrincipal),
            borrower,
            seizeTokens,
            address(fTokenCollateral),
            tokenCash(address(fTokenCollateral), borrower),
            accountBorrows[borrower].principal, //debt_remaining
            exchangeRateAfter(actualRepayAmount),
            interestRateModel.getBorrowRate(
                preCalcTokenCash,
                totalBorrows,
                totalReserves
            ),
            tokenCash(address(fTokenCollateral), liquidator),
            preCalcTokenCash
        );

        return abi.encode(lbls);
    }

    function seize(
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external nonReentrant {
        return seizeInternal(msg.sender, liquidator, borrower, seizeTokens);
    }

    struct CallingOutLogStruct {
        address user_address;
        address token_address;
        address cheque_token_address;
        uint256 amount_wiped_out;
        uint256 debt_cancelled_out;
        uint256 interest_accrued;
        uint256 cheque_token_value;
        uint256 loan_interest_rate;
        uint256 account_balance;
        uint256 account_debt;
        uint256 global_token_reserved;
    }

    //冲账处理
    function cancellingOut(address striker)
        public
        onlyBank
        nonReentrant
        returns (bool strikeOk, bytes memory strikeLog)
    {
        // 需要冲账时，计算利息
        if (
            borrowBalanceStoredInternal(striker) > 0 && balanceOf(striker) > 0
        ) {
            accrueInterest();
            uint256 lastPrincipal = accountBorrows[striker].principal;
            uint256 curBorrowBalance = borrowBalanceStoredInternal(striker);
            uint256 userSupplyBalance = calcBalanceOfUnderlying(striker);
            uint256 lastFtokenBalance = balanceOf(striker);
            uint256 actualRepayAmount;
            bytes memory repayLog;
            uint256 withdrawAmount;
            bytes memory withdrawLog;
            // 有借款和存款(fToken)
            if (curBorrowBalance > 0 && userSupplyBalance > 0) {
                //无实际转账的赎回（冲账赎回）
                if (userSupplyBalance > curBorrowBalance) {
                    (withdrawAmount, withdrawLog) = strikeWithdrawInternal(
                        striker,
                        0,
                        curBorrowBalance
                    );
                } else {
                    (withdrawAmount, withdrawLog) = strikeWithdrawInternal(
                        striker,
                        balanceOf(striker),
                        0
                    );
                }

                (actualRepayAmount, repayLog) = repayInternal(
                    striker,
                    withdrawAmount
                );

                CallingOutLogStruct memory cols;

                cols.user_address = striker;
                cols.token_address = underlying;
                cols.cheque_token_address = address(this);
                cols.amount_wiped_out = SafeMath.abs(
                    lastFtokenBalance,
                    balanceOf(striker)
                );
                cols.debt_cancelled_out = actualRepayAmount;
                cols.interest_accrued = SafeMath.abs(
                    curBorrowBalance,
                    lastPrincipal
                );
                cols.cheque_token_value = exchangeRateStored();
                cols.loan_interest_rate = interestRateModel.getBorrowRate(
                    tokenCash(underlying, address(controller)),
                    totalBorrows,
                    totalReserves
                );
                cols.account_balance = tokenCash(address(this), striker);
                cols.account_debt = accountBorrows[striker].principal;
                cols.global_token_reserved = tokenCash(
                    underlying,
                    address(controller)
                );

                strikeLog = abi.encode(cols);

                strikeOk = true;
            }
        }
    }

    function balanceOf(address owner) public view returns (uint256) {
        return accountTokens[owner];
    }

    function _setBorrowSafeRatio(uint256 _borrowSafeRatio) public onlyAdmin {
        borrowSafeRatio = _borrowSafeRatio;
    }

    function seizeInternal(
        address seizerToken,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) internal {
        require(borrower != liquidator, "Liquidator cannot be borrower");
        controller.seizeCheck(msg.sender, seizerToken);

        accountTokens[borrower] = accountTokens[borrower].sub(seizeTokens);
        accountTokens[liquidator] = accountTokens[liquidator].add(seizeTokens);

        emit Transfer(borrower, liquidator, seizeTokens);
    }

    // onlyController
    function _reduceReserves(uint256 reduceAmount) external onlyController {
        accrueInterest();

        require(accrualBlockNumber == getBlockNumber(), "Blocknumber fails");
        require(
            controller.getCashPrior(underlying) >= reduceAmount,
            "Insufficient cash"
        );
        require(totalReserves >= reduceAmount, "Insufficient reserves");

        totalReserves = SafeMath.sub(
            totalReserves,
            reduceAmount,
            "reduce reserves underflow"
        );
    }

    function _addReservesFresh(uint256 addAmount) external onlyController {
        accrueInterest();

        require(accrualBlockNumber == getBlockNumber(), "Blocknumber fails");
        totalReserves = SafeMath.add(totalReserves, addAmount);
    }

    function addTotalCash(uint256 _addAmount) public onlyBankComponent {
        totalCash = totalCash.add(_addAmount);
    }

    function subTotalCash(uint256 _subAmount) public onlyBankComponent {
        totalCash = totalCash.sub(_subAmount);
    }

    modifier nonReentrant() {
        require(_notEntered, "re-entered");
        _notEntered = false;
        _;
        _notEntered = true;
    }

    // 借款年利率
    function APR() public view returns (uint256) {
        uint256 cash = tokenCash(underlying, address(controller));
        return interestRateModel.APR(cash, totalBorrows, totalReserves);
    }

    // 存款年利率
    function APY() external view returns (uint256) {
        uint256 cash = tokenCash(underlying, address(controller));
        return
            interestRateModel.APY(
                cash,
                totalBorrows,
                totalReserves,
                reserveFactor
            );
    }

    // 借款年利率
    function getBorrowRate() public view returns (uint256) {
        uint256 cash = tokenCash(underlying, address(controller));
        return
            interestRateModel.getBorrowRate(cash, totalBorrows, totalReserves);
    }

    // 存款年利率
    function getSupplyRate() public view returns (uint256) {
        uint256 cash = tokenCash(underlying, address(controller));
        return
            interestRateModel.getSupplyRate(
                cash,
                totalBorrows,
                totalReserves,
                reserveFactor
            );
    }
}
