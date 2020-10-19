// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity 0.6.4;

import "./library/EthAddressLib.sol";
import "./Exponential.sol";
import "./interface/IFToken.sol";
import "./interface/IOracle.sol";
import "./interface/IERC20.sol";
import "./library/SafeERC20.sol";
import "./RewardType.sol";
import "./library/SafeMath.sol";
import "./interface/IBank.sol";
import "./interface/IRewardPool.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";

contract BankController is Exponential, Initializable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct Market {
        // 原生币种对应的 fToken 地址
        address fTokenAddress;
        // 币种是否可用
        bool isValid;
        // 该币种所拥有的质押能力
        uint256 collateralAbility;
        // 市场所参与的用户
        mapping(address => bool) accountsIn;
        // 该币种的清算奖励
        uint256 liquidationIncentive;
    }

    // 原生币种地址 => 币种信息
    mapping(address => Market) public markets;

    address public bankEntryAddress; // bank主合约入口地址
    address public theForceToken; // 奖励的FOR token地址

    //返利百分比，根据用户存，借，取，还花费的gas返还对应价值比例的奖励token， 奖励FOR数量 = ETH价值 * rewardFactor / price(for)， 1e18 scale
    mapping(uint256 => uint256) public rewardFactors; // RewardType ==> rewardFactor (1e18 scale);

    // 用户地址 =》 币种地址（用户参与的币种）
    mapping(address => IFToken[]) public accountAssets;

    IFToken[] public allMarkets;

    address[] public allUnderlyingMarkets;

    IOracle public oracle;

    address public mulsig;

    //FIXME: 统一权限管理
    modifier auth {
        require(
            msg.sender == admin || msg.sender == bankEntryAddress,
            "msg.sender need admin or bank"
        );
        _;
    }

    function setBankEntryAddress(address _newBank) external auth {
        bankEntryAddress = _newBank;
    }

    function setTheForceToken(address _theForceToken) external auth {
        theForceToken = _theForceToken;
    }

    function setRewardFactorByType(uint256 rewaradType, uint256 factor)
        external
        auth
    {
        rewardFactors[rewaradType] = factor;
    }

    function marketsContains(address fToken) public view returns (bool) {
        uint256 len = allMarkets.length;
        for (uint256 i = 0; i < len; ++i) {
            if (address(allMarkets[i]) == fToken) {
                return true;
            }
        }
        return false;
    }

    uint256 public closeFactor;

    address public admin;

    address public proposedAdmin;

    // 将FOR奖励池单独放到另外一个合约中
    address public rewardPool;

    uint256 public transferEthGasCost;

    function initialize(address _mulsig) public initializer {
        admin = msg.sender;
        mulsig = _mulsig;
        transferEthGasCost = 5000;
    }

    modifier onlyMulSig {
        require(msg.sender == mulsig, "require admin");
        _;
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "require admin");
        _;
    }

    modifier onlyFToken(address fToken) {
        require(marketsContains(fToken), "only supported fToken");
        _;
    }

    event AddTokenToMarket(address underlying, address fToken);

    function proposeNewAdmin(address admin_) external onlyMulSig {
        proposedAdmin = admin_;
    }

    function claimAdministration() external {
        require(msg.sender == proposedAdmin, "Not proposed admin.");
        admin = proposedAdmin;
        proposedAdmin = address(0);
    }

    // 获取原生 token 对应的 fToken 地址
    function getFTokeAddress(address underlying) public view returns (address) {
        return markets[underlying].fTokenAddress;
    }

    /**
     * @notice Returns the assets an account has entered
     返回该账户已经参与的币种
     * @param account The address of the account to pull assets for
     * @return A dynamic list with the assets the account has entered
     */
    function getAssetsIn(address account)
        external
        view
        returns (IFToken[] memory)
    {
        IFToken[] memory assetsIn = accountAssets[account];

        return assetsIn;
    }

    function checkAccountsIn(address account, IFToken fToken)
        external
        view
        returns (bool)
    {
        return
            markets[IFToken(address(fToken)).underlying()].accountsIn[account];
    }

    function userEnterMarket(IFToken fToken, address borrower) internal {
        Market storage marketToJoin = markets[fToken.underlying()];

        require(marketToJoin.isValid, "Market not valid");

        if (marketToJoin.accountsIn[borrower]) {
            return;
        }

        marketToJoin.accountsIn[borrower] = true;

        accountAssets[borrower].push(fToken);
    }

    function transferCheck(
        address fToken,
        address src,
        address dst,
        uint256 transferTokens
    ) external onlyFToken(msg.sender) {
        withdrawCheck(fToken, src, transferTokens);
        userEnterMarket(IFToken(fToken), dst);
    }

    function withdrawCheck(
        address fToken,
        address withdrawer,
        uint256 withdrawTokens
    ) public view returns (uint256) {
        require(
            markets[IFToken(fToken).underlying()].isValid,
            "Market not valid"
        );

        (uint256 sumCollaterals, uint256 sumBorrows) = getUserLiquidity(
            withdrawer,
            IFToken(fToken),
            withdrawTokens,
            0
        );
        require(sumCollaterals >= sumBorrows, "Cannot withdraw tokens");
    }

    // 接收转账
    function transferIn(
        address account,
        address underlying,
        uint256 amount
    ) public payable {
        if (underlying != EthAddressLib.ethAddress()) {
            require(msg.value == 0, "ERC20 do not accecpt ETH.");
            uint256 balanceBefore = IERC20(underlying).balanceOf(address(this));
            IERC20(underlying).safeTransferFrom(account, address(this), amount);
            uint256 balanceAfter = IERC20(underlying).balanceOf(address(this));
            require(
                balanceAfter - balanceBefore == amount,
                "TransferIn amount not valid"
            );
            // erc 20 => transferFrom
        } else {
            // 接收 eth 转账，已经通过 payable 转入
            require(msg.value >= amount, "Eth value is not enough");
            if (msg.value > amount) {
                //send back excess ETH
                uint256 excessAmount = msg.value.sub(amount);
                //solium-disable-next-line
                (bool result, ) = account.call{
                    value: excessAmount,
                    gas: transferEthGasCost
                }("");
                require(result, "Transfer of ETH failed");
            }
        }
    }

    // 向用户转账
    function transferToUser(
        address underlying,
        address payable account,
        uint256 amount
    ) external onlyFToken(msg.sender) {
        require(
            markets[IFToken(msg.sender).underlying()].isValid,
            "TransferToUser not allowed"
        );
        transferToUserInternal(underlying, account, amount);
    }

    function transferToUserInternal(
        address underlying,
        address payable account,
        uint256 amount
    ) internal {
        if (underlying != EthAddressLib.ethAddress()) {
            // erc 20
            // ERC20(token).safeTransfer(user, _amount);
            IERC20(underlying).safeTransfer(account, amount);
        } else {
            (bool result, ) = account.call{
                value: amount,
                gas: transferEthGasCost
            }("");
            require(result, "Transfer of ETH failed");
        }
    }

    //1:1返还
    function calcRewardAmount(
        uint256 gasSpend,
        uint256 gasPrice,
        address _for
    ) public view returns (uint256) {
        (uint256 _ethPrice, bool _ethValid) = fetchAssetPrice(
            EthAddressLib.ethAddress()
        );
        (uint256 _forPrice, bool _forValid) = fetchAssetPrice(_for);
        if (!_ethValid || !_forValid || IERC20(_for).decimals() != 18) {
            return 0;
        }
        return gasSpend.mul(gasPrice).mul(_ethPrice).div(_forPrice);
    }

    //0.5 * 1e18, 表返还0.5ETH价值的FOR
    //1.5 * 1e18, 表返还1.5倍ETH价值的FOR
    function calcRewardAmountByFactor(
        uint256 gasSpend,
        uint256 gasPrice,
        address _for,
        uint256 factor
    ) public view returns (uint256) {
        return calcRewardAmount(gasSpend, gasPrice, _for).mul(factor).div(1e18);
    }

    function setRewardPool(address _rewardPool) external onlyAdmin {
        rewardPool = _rewardPool;
    }

    function setTransferEthGasCost(uint256 _transferEthGasCost)
        external
        onlyAdmin
    {
        transferEthGasCost = _transferEthGasCost;
    }

    function rewardForByType(
        address account,
        uint256 gasSpend,
        uint256 gasPrice,
        uint256 rewardType
    ) external auth {
        uint256 amount = calcRewardAmountByFactor(
            gasSpend,
            gasPrice,
            theForceToken,
            rewardFactors[rewardType]
        );
        amount = SafeMath.min(
            amount,
            IERC20(theForceToken).balanceOf(rewardPool)
        );
        if (amount > 0) {
            IRewardPool(rewardPool).reward(account, amount);
        }
    }

    // 获取实际原生代币的余额
    function getCashPrior(address underlying) public view returns (uint256) {
        IFToken fToken = IFToken(getFTokeAddress(underlying));
        return fToken.totalCash();
    }

    // 获取将要更新后的原生代币的余额（预判）
    function getCashAfter(address underlying, uint256 transferInAmount)
        external
        view
        returns (uint256)
    {
        return getCashPrior(underlying).add(transferInAmount);
    }

    function mintCheck(address underlying, address minter) external {
        require(
            markets[IFToken(msg.sender).underlying()].isValid,
            "MintCheck fails"
        );
        require(markets[underlying].isValid, "Market not valid");
        if (!markets[underlying].accountsIn[minter]) {
            userEnterMarket(IFToken(getFTokeAddress(underlying)), minter);
        }
    }

    function borrowCheck(
        address account,
        address underlying,
        address fToken,
        uint256 borrowAmount
    ) external {
        require(
            markets[IFToken(msg.sender).underlying()].isValid,
            "BorrowCheck fails"
        );
        require(markets[underlying].isValid, "Market not valid");
        (, bool valid) = fetchAssetPrice(underlying);
        require(valid, "Price is not valid");
        if (!markets[underlying].accountsIn[account]) {
            userEnterMarket(IFToken(getFTokeAddress(underlying)), account);
        }
        // 校验用户流动性，liquidity
        (uint256 sumCollaterals, uint256 sumBorrows) = getUserLiquidity(
            account,
            IFToken(fToken),
            0,
            borrowAmount
        );
        require(sumBorrows > 0, "borrow value too low");
        require(sumCollaterals >= sumBorrows, "insufficient liquidity");
    }

    function repayCheck(address underlying) external view {
        require(markets[underlying].isValid, "Market not valid");
    }

    // 获取用户总体的存款和借款情况
    function getTotalDepositAndBorrow(address account)
        public
        view
        returns (uint256, uint256)
    {
        return getUserLiquidity(account, IFToken(0), 0, 0);
    }

    // 获取账户流动性
    function getAccountLiquidity(address account)
        public
        view
        returns (uint256 liquidity, uint256 shortfall)
    {
        (uint256 sumCollaterals, uint256 sumBorrows) = getUserLiquidity(
            account,
            IFToken(0),
            0,
            0
        );
        // These are safe, as the underflow condition is checked first
        if (sumCollaterals > sumBorrows) {
            return (sumCollaterals - sumBorrows, 0);
        } else {
            return (0, sumBorrows - sumCollaterals);
        }
    }

    // 不包含FToken的流动性
    function getAccountLiquidityExcludeDeposit(address account, address token)
        public
        view
        returns (uint256, uint256)
    {
        IFToken fToken = IFToken(getFTokeAddress(token));
        (uint256 sumCollaterals, uint256 sumBorrows) = getUserLiquidity(
            account,
            fToken,
            fToken.balanceOf(account), //用户的fToken数量
            0
        );

        // These are safe, as the underflow condition is checked first
        if (sumCollaterals > sumBorrows) {
            return (sumCollaterals - sumBorrows, 0);
        } else {
            return (0, sumBorrows - sumCollaterals);
        }
    }

    // Get price of oracle
    function fetchAssetPrice(address token)
        public
        view
        returns (uint256, bool)
    {
        require(address(oracle) != address(0), "oracle not set");
        return oracle.get(token);
    }

    function setOracle(address _oracle) external onlyAdmin {
        oracle = IOracle(_oracle);
    }

    function _supportMarket(
        IFToken fToken,
        uint256 _collateralAbility,
        uint256 _liquidationIncentive
    ) public onlyAdmin {
        address underlying = fToken.underlying();

        require(!markets[underlying].isValid, "martket existed");

        markets[underlying] = Market({
            isValid: true,
            collateralAbility: _collateralAbility,
            fTokenAddress: address(fToken),
            liquidationIncentive: _liquidationIncentive
        });

        addTokenToMarket(underlying, address(fToken));
    }

    function addTokenToMarket(address underlying, address fToken) internal {
        for (uint256 i = 0; i < allUnderlyingMarkets.length; i++) {
            require(
                allUnderlyingMarkets[i] != underlying,
                "token exists"
            );
            require(allMarkets[i] != IFToken(fToken), "token exists");
        }
        allMarkets.push(IFToken(fToken));
        allUnderlyingMarkets.push(underlying);

        emit AddTokenToMarket(underlying, fToken);
    }

    function _setCollateralAbility(
        address underlying,
        uint256 newCollateralAbility
    ) external onlyAdmin {
        require(markets[underlying].isValid, "Market not valid");

        Market storage market = markets[underlying];

        market.collateralAbility = newCollateralAbility;
    }

    function setCloseFactor(uint256 _closeFactor) external onlyAdmin {
        closeFactor = _closeFactor;
    }

    /**
     * @notice Return all of the markets
     * @dev The automatic getter may be used to access an individual market.
     * @return The list of market addresses
     */
    function getAllMarkets() external view returns (IFToken[] memory) {
        return allMarkets;
    }

    function seizeCheck(address cTokenCollateral, address cTokenBorrowed)
        external
        view
        onlyFToken(msg.sender)
    {
        require(
            markets[IFToken(cTokenCollateral).underlying()].isValid &&
                markets[IFToken(cTokenBorrowed).underlying()].isValid,
            "Seize market not valid"
        );
    }

    struct LiquidityLocals {
        uint256 sumCollateral;
        uint256 sumBorrows;
        uint256 fTokenBalance;
        uint256 borrowBalance;
        uint256 exchangeRate;
        uint256 oraclePrice;
        uint256 collateralAbility;
        uint256 collateral;
    }

    function getUserLiquidity(
        address account,
        IFToken fTokenNow,
        uint256 withdrawTokens,
        uint256 borrowAmount
    ) public view returns (uint256, uint256) {
        // 用户参与的每个币种
        IFToken[] memory assets = accountAssets[account];
        LiquidityLocals memory vars;
        // 对于每个币种
        for (uint256 i = 0; i < assets.length; i++) {
            IFToken asset = assets[i];
            // 获取 fToken 的余额和兑换率
            (vars.fTokenBalance, vars.borrowBalance, vars.exchangeRate) = asset
                .getAccountState(account);
            // 该币种的质押率
            vars.collateralAbility = markets[asset.underlying()]
                .collateralAbility;
            // 获取币种价格
            (uint256 oraclePrice, bool valid) = fetchAssetPrice(
                asset.underlying()
            );
            require(valid, "Price is not valid");
            vars.oraclePrice = oraclePrice;

            uint256 fixUnit = calcExchangeUnit(address(asset));
            uint256 exchangeRateFixed = mulScalar(vars.exchangeRate, fixUnit);

            vars.collateral = mulExp3(
                vars.collateralAbility,
                exchangeRateFixed,
                vars.oraclePrice
            );

            vars.sumCollateral = mulScalarTruncateAddUInt(
                vars.collateral,
                vars.fTokenBalance,
                vars.sumCollateral
            );

            vars.borrowBalance = vars.borrowBalance.mul(fixUnit);

            vars.sumBorrows = mulScalarTruncateAddUInt(
                vars.oraclePrice,
                vars.borrowBalance,
                vars.sumBorrows
            );

            // 借款和取款的时候，将当前要操作的数量，直接计算在账户流动性里面
            if (asset == fTokenNow) {
                // 取款
                vars.sumBorrows = mulScalarTruncateAddUInt(
                    vars.collateral,
                    withdrawTokens,
                    vars.sumBorrows
                );

                borrowAmount = borrowAmount.mul(fixUnit);

                // 借款
                vars.sumBorrows = mulScalarTruncateAddUInt(
                    vars.oraclePrice,
                    borrowAmount,
                    vars.sumBorrows
                );
            }
        }

        return (vars.sumCollateral, vars.sumBorrows);
    }

    //不包含某一token的流动性
    function getUserLiquidityExcludeToken(
        address account,
        IFToken excludeToken,
        IFToken fTokenNow,
        uint256 withdrawTokens,
        uint256 borrowAmount
    ) external view returns (uint256, uint256) {
        // 用户参与的每个币种
        IFToken[] memory assets = accountAssets[account];
        LiquidityLocals memory vars;
        // 对于每个币种
        for (uint256 i = 0; i < assets.length; i++) {
            IFToken asset = assets[i];

            //不包含token
            if (address(asset) == address(excludeToken)) {
                continue;
            }

            // 获取 fToken 的余额和兑换率
            (vars.fTokenBalance, vars.borrowBalance, vars.exchangeRate) = asset
                .getAccountState(account);
            // 该币种的质押率
            vars.collateralAbility = markets[asset.underlying()]
                .collateralAbility;
            // 获取币种价格
            (uint256 oraclePrice, bool valid) = fetchAssetPrice(
                asset.underlying()
            );
            require(valid, "Price is not valid");
            vars.oraclePrice = oraclePrice;

            uint256 fixUnit = calcExchangeUnit(address(asset));
            uint256 exchangeRateFixed = mulScalar(
                vars.exchangeRate,
                fixUnit
            );

            vars.collateral = mulExp3(
                vars.collateralAbility,
                exchangeRateFixed,
                vars.oraclePrice
            );

            vars.sumCollateral = mulScalarTruncateAddUInt(
                vars.collateral,
                vars.fTokenBalance,
                vars.sumCollateral
            );

            vars.sumBorrows = mulScalarTruncateAddUInt(
                vars.oraclePrice,
                vars.borrowBalance,
                vars.sumBorrows
            );

            // 借款和取款的时候，将当前要操作的数量，直接计算在账户流动性里面
            if (asset == fTokenNow) {
                // 取款
                vars.sumBorrows = mulScalarTruncateAddUInt(
                    vars.collateral,
                    withdrawTokens,
                    vars.sumBorrows
                );

                borrowAmount = borrowAmount.mul(fixUnit);

                // 借款
                vars.sumBorrows = mulScalarTruncateAddUInt(
                    vars.oraclePrice,
                    borrowAmount,
                    vars.sumBorrows
                );
            }
        }

        return (vars.sumCollateral, vars.sumBorrows);
    }

    function tokenDecimals(address token) public view returns (uint256) {
        return
            token == EthAddressLib.ethAddress()
                ? 18
                : uint256(IERC20(token).decimals());
    }

    //计算user的取款指定token的最大数量
    function calcMaxWithdrawAmount(address user, address token)
        public
        view
        returns (uint256)
    {
        (uint256 depoistValue, uint256 borrowValue) = getTotalDepositAndBorrow(
            user
        );
        if (depoistValue <= borrowValue) {
            return 0;
        }

        uint256 netValue = subExp(depoistValue, borrowValue);
        // redeemValue = netValue / collateralAblility;
        uint256 redeemValue = divExp(
            netValue,
            markets[token].collateralAbility
        );

        (uint256 oraclePrice, bool valid) = fetchAssetPrice(token);
        require(valid, "Price is not valid");

        uint fixUnit = 10 ** SafeMath.abs(18, tokenDecimals(token));
        uint256 redeemAmount = divExp(redeemValue, oraclePrice).div(fixUnit);
        IFToken fToken = IFToken(getFTokeAddress(token));

        redeemAmount = SafeMath.min(
            redeemAmount,
            fToken.calcBalanceOfUnderlying(user)
        );
        return redeemAmount;
    }

    function calcMaxBorrowAmount(address user, address token)
        public
        view
        returns (uint256)
    {
        (
            uint256 depoistValue,
            uint256 borrowValue
        ) = getAccountLiquidityExcludeDeposit(user, token);
        if (depoistValue <= borrowValue) {
            return 0;
        }
        uint256 netValue = subExp(depoistValue, borrowValue);
        (uint256 oraclePrice, bool valid) = fetchAssetPrice(token);
        require(valid, "Price is not valid");

        uint fixUnit = 10 ** SafeMath.abs(18, tokenDecimals(token));
        uint256 borrowAmount = divExp(netValue, oraclePrice).div(fixUnit);

        return borrowAmount;
    }

    function calcMaxBorrowAmountWithRatio(address user, address token)
        public
        view
        returns (uint256)
    {
        IFToken fToken = IFToken(getFTokeAddress(token));

        return
            SafeMath.mul(calcMaxBorrowAmount(user, token), 1e18).div(fToken.borrowSafeRatio());
    }

    function calcMaxCashOutAmount(address user, address token)
        public
        view
        returns (uint256)
    {
        return
            addExp(
                calcMaxWithdrawAmount(user, token),
                calcMaxBorrowAmountWithRatio(user, token)
            );
    }

    function isFTokenValid(address fToken) external view returns (bool) {
        return markets[IFToken(fToken).underlying()].isValid;
    }

    function liquidateBorrowCheck(
        address fTokenBorrowed,
        address fTokenCollateral,
        address borrower,
        address liquidator,
        uint256 repayAmount
    ) external onlyFToken(msg.sender) {
        (, uint256 shortfall) = getAccountLiquidity(borrower);
        require(shortfall != 0, "Insufficient shortfall");
        userEnterMarket(IFToken(fTokenCollateral), liquidator);

        uint256 borrowBalance = IFToken(fTokenBorrowed).borrowBalanceStored(
            borrower
        );
        uint256 maxClose = mulScalarTruncate(closeFactor, borrowBalance);
        require(repayAmount <= maxClose, "Too much repay");
    }

    function calcExchangeUnit(address fToken) public view returns (uint256) {
        uint256 fTokenDecimals = uint256(IFToken(fToken).decimals());
        uint256 underlyingDecimals = IFToken(fToken).underlying() ==
            EthAddressLib.ethAddress()
            ? 18
            : uint256(IERC20(IFToken(fToken).underlying()).decimals());

        return 10**SafeMath.abs(fTokenDecimals, underlyingDecimals);
    }

    function liquidateTokens(
        address fTokenBorrowed,
        address fTokenCollateral,
        uint256 actualRepayAmount
    ) external view returns (uint256) {
        (uint256 borrowPrice, bool borrowValid) = fetchAssetPrice(
            IFToken(fTokenBorrowed).underlying()
        );
        (uint256 collateralPrice, bool collateralValid) = fetchAssetPrice(
            IFToken(fTokenCollateral).underlying()
        );
        require(borrowValid && collateralValid, "Price not valid");

        /*
         *  seizeAmount = actualRepayAmount * liquidationIncentive * priceBorrowed / priceCollateral
         *  seizeTokens = seizeAmount / exchangeRate
         *   = actualRepayAmount * (liquidationIncentive * priceBorrowed) / (priceCollateral * exchangeRate)
         */
        uint256 exchangeRate = IFToken(fTokenCollateral).exchangeRateStored();

        uint256 fixCollateralUnit = calcExchangeUnit(fTokenCollateral);
        uint256 fixBorrowlUnit = calcExchangeUnit(fTokenBorrowed);

        uint256 numerator = mulExp(
            markets[IFToken(fTokenCollateral).underlying()]
                .liquidationIncentive,
            borrowPrice
        );
        exchangeRate = exchangeRate.mul(fixCollateralUnit);

        actualRepayAmount = actualRepayAmount.mul(fixBorrowlUnit);

        uint256 denominator = mulExp(collateralPrice, exchangeRate);
        uint256 seizeTokens = mulScalarTruncate(
            divExp(numerator, denominator),
            actualRepayAmount
        );

        return seizeTokens;
    }

    function _setLiquidationIncentive(
        address underlying,
        uint256 _liquidationIncentive
    ) public onlyAdmin {
        markets[underlying].liquidationIncentive = _liquidationIncentive;
    }

    struct ReserveWithdrawalLogStruct {
        address token_address;
        uint256 reserve_withdrawed;
        uint256 cheque_token_value;
        uint256 loan_interest_rate;
        uint256 global_token_reserved;
    }

    function reduceReserves(
        address underlying,
        address payable account,
        uint256 reduceAmount
    ) public onlyMulSig {
        IFToken fToken = IFToken(getFTokeAddress(underlying));
        fToken._reduceReserves(reduceAmount);
        transferToUserInternal(underlying, account, reduceAmount);
        fToken.subTotalCash(reduceAmount);

        ReserveWithdrawalLogStruct memory rds = ReserveWithdrawalLogStruct(
            underlying,
            reduceAmount,
            fToken.exchangeRateStored(),
            fToken.getBorrowRate(),
            fToken.tokenCash(underlying, address(this))
        );

        IBank(bankEntryAddress).MonitorEventCallback(
            "ReserveWithdrawal",
            abi.encode(rds)
        );
    }

    function batchReduceReserves(
        address[] calldata underlyings,
        address payable account,
        uint256[] calldata reduceAmounts
    ) external onlyMulSig {
        require(underlyings.length == reduceAmounts.length, "length not match");
        uint256 n = underlyings.length;
        for (uint256 i = 0; i < n; i++) {
            reduceReserves(underlyings[i], account, reduceAmounts[i]);
        }
    }

    function batchReduceAllReserves(
        address[] calldata underlyings,
        address payable account
    ) external onlyMulSig {
        uint256 n = underlyings.length;
        for (uint i = 0; i < n; i++) {
            IFToken fToken = IFToken(getFTokeAddress(underlyings[i]));
            uint256 amount = SafeMath.min(fToken.totalReserves(), fToken.tokenCash(underlyings[i], address(this)));
            if (amount > 0) {
                reduceReserves(underlyings[i], account, amount);
            }
        }
    }

    function batchReduceAllReserves(
        address payable account
    ) external onlyMulSig {
        uint256 n = allUnderlyingMarkets.length;
        for (uint i = 0; i < n; i++) {
            address underlying = allUnderlyingMarkets[i];
            IFToken fToken = IFToken(getFTokeAddress(underlying));
            uint256 amount = SafeMath.min(fToken.totalReserves(), fToken.tokenCash(underlying, address(this)));
            if (amount > 0) {
                reduceReserves(underlying, account, amount);
            }
        }
    }

    struct ReserveDepositLogStruct {
        address token_address;
        uint256 reserve_funded;
        uint256 cheque_token_value;
        uint256 loan_interest_rate;
        uint256 global_token_reserved;
    }

    function addReserves(address underlying, uint256 addAmount)
        external
        payable
    {
        IFToken fToken = IFToken(getFTokeAddress(underlying));
        fToken._addReservesFresh(addAmount);
        transferIn(msg.sender, underlying, addAmount);
        fToken.addTotalCash(addAmount);

        ReserveDepositLogStruct memory rds = ReserveDepositLogStruct(
            underlying,
            addAmount,
            fToken.exchangeRateStored(),
            fToken.getBorrowRate(),
            fToken.tokenCash(underlying, address(this))
        );

        IBank(bankEntryAddress).MonitorEventCallback(
            "ReserveDeposit",
            abi.encode(rds)
        );
    }
}
