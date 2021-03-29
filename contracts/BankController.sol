// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity 0.6.4;

import "./library/EthAddressLib.sol";
import "./library/Address.sol";
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
    using Address for address;

    struct Market {
        // The fToken address corresponding to the underlying asset
        address fTokenAddress;
        // Whether the market is available
        bool isValid;
        // The loan-to-value ratio owned by the underlying asset
        uint256 collateralAbility;
        // account's mapping in this market
        mapping(address => bool) accountsIn;
        // The liquidation incentive of the underlying asset
        uint256 liquidationIncentive;
    }

    // underlying => market
    mapping(address => Market) public markets;

    address public bankEntryAddress;
    address public theForceToken;

    mapping(uint256 => uint256) public rewardFactors; // RewardType ==> rewardFactor (1e18 scale);

    mapping(address => IFToken[]) public accountAssets;

    IFToken[] public allMarkets;

    address[] public allUnderlyingMarkets;

    IOracle public oracle;

    address public mulsig;

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

    function marketsContains(address fToken) public view returns (bool) {
        return allFtokenMarkets[fToken];
    }

    uint256 public closeFactor;

    address public admin;

    address public proposedAdmin;

    address public rewardPool;

    uint256 public transferEthGasCost;

    // @notice Borrow caps enforced by borrowAllowed for each token address. Defaults to zero which corresponds to unlimited borrowing.
    mapping(address => uint) public borrowCaps;
    
    // @notice Supply caps enforced by mintAllowed for each token address. Defaults to zero which corresponds to unlimited supplying.
    mapping(address => uint) public supplyCaps;

    struct TokenConfig {
        bool depositDisabled;
        bool borrowDisabled;
        bool withdrawDisabled;
        bool repayDisabled;
        bool liquidateBorrowDisabled;
    }
    
    //underlying => TokenConfig
    mapping (address => TokenConfig) public tokenConfigs;

    mapping (address => uint256) public underlyingLiquidationThresholds;
    event SetLiquidationThreshold(address indexed underlying, uint256 threshold);

    bool private entered;
    modifier nonReentrant() {
        require(!entered, "re-entered");
        entered = true;
        _;
        entered = false;
    }

    uint256 public flashloanFeeBips; // Nine out of ten thousand，9 for 0.0009
    address public flashloanVault;// flash loan vault(recv flash loan fee);
    event SetFlashloanParams(address indexed sender, uint256 bips, address flashloanVault);

    // fToken => supported or not, using mapping to save gas instead of iterator array
    mapping (address => bool) public allFtokenMarkets;
    event SetAllFtokenMarkets(bytes data);

    // fToken => exchangeUnit, to save gas instead of runtime calc
    mapping (address => uint256) public allFtokenExchangeUnits;

    // _setMarketBorrowSupplyCaps = _setMarketBorrowCaps + _setMarketSupplyCaps
    function _setMarketBorrowSupplyCaps(address[] calldata tokens, uint[] calldata newBorrowCaps, uint[] calldata newSupplyCaps) external {
        require(msg.sender == admin, "only admin can set borrow/supply caps"); 

        uint numMarkets = tokens.length;
        uint numBorrowCaps = newBorrowCaps.length;
        uint numSupplyCaps = newSupplyCaps.length;

        require(numMarkets != 0 && numMarkets == numBorrowCaps && numMarkets == numSupplyCaps, "invalid input");

        for(uint i = 0; i < numMarkets; i++) {
            borrowCaps[tokens[i]] = newBorrowCaps[i];
            supplyCaps[tokens[i]] = newSupplyCaps[i];
        }
    }

    
    function setTokenConfig(
        address t, 
        bool _depositDisabled, 
        bool _borrowDisabled, 
        bool _withdrawDisabled,
        bool _repayDisabled,
        bool _liquidateBorrowDisabled) external {
        require(msg.sender == admin, "only admin can set token configs");
        tokenConfigs[t] = TokenConfig(
            _depositDisabled,
            _borrowDisabled,
            _withdrawDisabled,
            _repayDisabled,
            _liquidateBorrowDisabled
        );
    }

    function setLiquidationThresolds(address[] calldata underlyings, uint256[] calldata _liquidationThresolds) external onlyAdmin {
        uint256 n = underlyings.length;
        require(n == _liquidationThresolds.length && n >= 1, "length: wtf?");
        for (uint i = 0; i < n; i++) {
            uint256 ltv = markets[underlyings[i]].collateralAbility;
            require(ltv <= _liquidationThresolds[i], "risk param error");
            underlyingLiquidationThresholds[underlyings[i]] = _liquidationThresolds[i];
            emit SetLiquidationThreshold(underlyings[i], _liquidationThresolds[i]);
        }
    }

    function setFlashloanParams(uint256 _flashloanFeeBips, address _flashloanVault) external onlyAdmin {
        require(_flashloanFeeBips <= 10000 && _flashloanVault != address(0), "flashloan param error");
        flashloanFeeBips = _flashloanFeeBips;
        flashloanVault = _flashloanVault;
        emit SetFlashloanParams(msg.sender, _flashloanFeeBips, _flashloanVault);
    }

    function setAllFtokenMarkets(address[] calldata ftokens) external onlyAdmin {
        uint256 n = ftokens.length;
        for (uint256 i = 0; i < n; i++) {
            allFtokenMarkets[ftokens[i]] = true;
            allFtokenExchangeUnits[ftokens[i]] = _calcExchangeUnit(ftokens[i]);
        }
        emit SetAllFtokenMarkets(abi.encode(ftokens));
    }

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
        address underlying = IFToken(fToken).underlying();
        require(
            markets[underlying].isValid,
            "Market not valid"
        );
        require(!tokenConfigs[underlying].withdrawDisabled, "withdraw disabled");

        (uint256 sumCollaterals, uint256 sumBorrows) = getUserLiquidity(
            withdrawer,
            IFToken(fToken),
            withdrawTokens,
            0
        );
        require(sumCollaterals >= sumBorrows, "Cannot withdraw tokens");
    }

    // Receive transfer
    function transferIn(
        address account,
        address underlying,
        uint256 amount
    ) public nonReentrant payable {
	require(msg.sender == bankEntryAddress || msg.sender == account, "auth failed");
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
            // Receive eth transfer, which has been transferred through payable
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

    // Transfer underlying to user
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

    // Transfer underlying to flashloan user
    function transferFlashloanAsset(
        address underlying,
        address payable account,
        uint256 amount
    ) external {
        require(
            msg.sender == bankEntryAddress,
            "only bank auth"
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

    function setTransferEthGasCost(uint256 _transferEthGasCost)
        external
        onlyAdmin
    {
        transferEthGasCost = _transferEthGasCost;
    }

    // Get the balance of the actual unerderlying asset
    function getCashPrior(address underlying) public view returns (uint256) {
        IFToken fToken = IFToken(getFTokeAddress(underlying));
        return fToken.totalCash();
    }

    // Get the balance of the underlying assets to be updated (pre-judgment)
    function getCashAfter(address underlying, uint256 transferInAmount)
        external
        view
        returns (uint256)
    {
        return getCashPrior(underlying).add(transferInAmount);
    }

    function mintCheck(address underlying, address minter, uint256 amount) external {
        require(marketsContains(msg.sender), "MintCheck fails");
        require(markets[underlying].isValid, "Market not valid");
        require(!tokenConfigs[underlying].depositDisabled, "deposit disabled");

        uint supplyCap = supplyCaps[underlying];
        // Supply cap of 0 corresponds to unlimited supplying
        if (supplyCap != 0) {
            uint totalSupply = IFToken(msg.sender).totalSupply();
            uint _exchangeRate = IFToken(msg.sender).exchangeRateStored();
            // Number of underlying assets = exchange rate multiplied by the total number of issued ftokens
            uint256 totalUnderlyingSupply = mulScalarTruncate(_exchangeRate, totalSupply);
            uint nextTotalUnderlyingSupply = totalUnderlyingSupply.add(amount);
            require(nextTotalUnderlyingSupply < supplyCap, "market supply cap reached");
        }

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
        require(underlying == IFToken(msg.sender).underlying(), "invalid underlying token");
        require(
            markets[underlying].isValid,
            "BorrowCheck fails"
        );
        require(!tokenConfigs[underlying].borrowDisabled, "borrow disabled");

        uint borrowCap = borrowCaps[underlying];
        // Borrow cap of 0 corresponds to unlimited borrowing
        if (borrowCap != 0) {
            uint totalBorrows = IFToken(msg.sender).totalBorrows();
            uint nextTotalBorrows = totalBorrows.add(borrowAmount);
            require(nextTotalBorrows < borrowCap, "market borrow cap reached");
        }

        require(markets[underlying].isValid, "Market not valid");
        (, bool valid) = fetchAssetPrice(underlying);
        require(valid, "Price is not valid");
        if (!markets[underlying].accountsIn[account]) {
            userEnterMarket(IFToken(getFTokeAddress(underlying)), account);
        }
        // Verify user liquidity
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
        require(!tokenConfigs[underlying].repayDisabled, "repay disabled");
    }

    // Get the user's overall deposit and borrowing status
    function getTotalDepositAndBorrow(address account)
        public
        view
        returns (uint256, uint256)
    {
        return getUserLiquidity(account, IFToken(0), 0, 0);
    }

    // Get account liquidity
    function getAccountLiquidity(address account)
        public
        view
        returns (uint256 liquidity, uint256 shortfall)
    {
        (uint256 sumCollaterals, uint256 sumBorrows) = getTotalDepositAndBorrow(account);
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
    ) external onlyAdmin {
        address underlying = fToken.underlying();

        require(!markets[underlying].isValid, "martket existed");
        require(tokenDecimals(underlying) <= 18, "unsupported token decimals");

        markets[underlying] = Market({
            isValid: true,
            collateralAbility: _collateralAbility,
            fTokenAddress: address(fToken),
            liquidationIncentive: _liquidationIncentive
        });

        addTokenToMarket(underlying, address(fToken));

        allFtokenMarkets[address(fToken)] = true;
        allFtokenExchangeUnits[address(fToken)] = _calcExchangeUnit(address(fToken));
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
        address[] calldata underlyings,
        uint256[] calldata newCollateralAbilities,
        uint256[] calldata _liquidationIncentives
    ) external onlyAdmin {
        uint256 n = underlyings.length;
        require(n == newCollateralAbilities.length && n == _liquidationIncentives.length && n >= 1, "invalid length");
        for (uint256 i = 0; i < n; i++) {
            address u = underlyings[i];
            require(markets[u].isValid, "Market not valid");
            Market storage market = markets[u];
            market.collateralAbility = newCollateralAbilities[i];
            market.liquidationIncentive = _liquidationIncentives[i];
        }
    }

    function setCloseFactor(uint256 _closeFactor) external onlyAdmin {
        closeFactor = _closeFactor;
    }

    // Set the transaction status of an asset, prohibit deposit, borrowing, repayment, liquidation and transfer.
    function setMarketIsValid(address underlying, bool isValid) external onlyAdmin {
        Market storage market = markets[underlying];
        market.isValid = isValid;
    }

    /**
     * @notice Return all of the markets
     * @dev The automatic getter may be used to access an individual market.
     * @return The list of market addresses
     */
    function getAllMarkets() external view returns (IFToken[] memory) {
        return allMarkets;
    }

    function seizeCheck(address fTokenCollateral, address fTokenBorrowed)
        external
        view
    {
        require(!IBank(bankEntryAddress).paused(), "system paused!");
        require(
            markets[IFToken(fTokenCollateral).underlying()].isValid &&
                markets[IFToken(fTokenBorrowed).underlying()].isValid && 
                marketsContains(fTokenCollateral) && marketsContains(fTokenBorrowed),
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
        IFToken[] memory assets = accountAssets[account];
        LiquidityLocals memory vars;
        for (uint256 i = 0; i < assets.length; i++) {
            IFToken asset = assets[i];
            // Get the balance and exchange rate of fToken
            (vars.fTokenBalance, vars.borrowBalance, vars.exchangeRate) = asset
                .getAccountState(account);
            // The ltv of the underling asset
            vars.collateralAbility = markets[asset.underlying()]
                .collateralAbility;
            // fetch asset price
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
            vars.borrowBalance = vars.borrowBalance.mul(1e18).div(vars.collateralAbility);

            vars.sumBorrows = mulScalarTruncateAddUInt(
                vars.oraclePrice,
                vars.borrowBalance,
                vars.sumBorrows
            );

            // When borrowing and withdrawing asset, the current amount to be operated is directly calculated in the account liquidity
            if (asset == fTokenNow) {
                // withdrawing
                vars.sumBorrows = mulScalarTruncateAddUInt(
                    vars.collateral,
                    withdrawTokens,
                    vars.sumBorrows
                );

                borrowAmount = borrowAmount.mul(fixUnit);
                borrowAmount = borrowAmount.mul(1e18).div(vars.collateralAbility);

                // borrowing
                vars.sumBorrows = mulScalarTruncateAddUInt(
                    vars.oraclePrice,
                    borrowAmount,
                    vars.sumBorrows
                );
            }
        }

        return (vars.sumCollateral, vars.sumBorrows);
    }

    struct HealthFactorLocals {
        uint256 sumLiquidity;
        uint256 sumLiquidityPlusThreshold;
        uint256 sumBorrows;
        uint256 fTokenBalance;
        uint256 borrowBalance;
        uint256 exchangeRate;
        uint256 oraclePrice;
        uint256 liquidationThreshold;
        uint256 liquidity;
        uint256 liquidityPlusThreshold;
    }

    function getHealthFactor(address account) public view returns (
        uint256 healthFactor
    ) {
        IFToken[] memory assets = accountAssets[account];
        HealthFactorLocals memory vars;
        uint256 _healthFactor = uint256(-1);
        for (uint256 i = 0; i < assets.length; i++) {
            IFToken asset = assets[i];
            address underlying = asset.underlying();
            (vars.fTokenBalance, vars.borrowBalance, vars.exchangeRate) = asset
                .getAccountState(account);
            vars.liquidationThreshold = underlyingLiquidationThresholds[underlying];    
            (uint256 oraclePrice, bool valid) = fetchAssetPrice(
                underlying
            );
            require(valid, "Price is not valid");
            vars.oraclePrice = oraclePrice;

            uint256 fixUnit = calcExchangeUnit(address(asset));
            uint256 exchangeRateFixed = mulScalar(vars.exchangeRate, fixUnit);

            vars.liquidityPlusThreshold = mulExp3(
                vars.liquidationThreshold,
                exchangeRateFixed,
                vars.oraclePrice
            );
            vars.sumLiquidityPlusThreshold = mulScalarTruncateAddUInt(
                vars.liquidityPlusThreshold,
                vars.fTokenBalance,
                vars.sumLiquidityPlusThreshold
            );

            vars.borrowBalance = vars.borrowBalance.mul(fixUnit);
            vars.borrowBalance = vars.borrowBalance.mul(1e18).div(vars.liquidationThreshold);

            vars.sumBorrows = mulScalarTruncateAddUInt(
                vars.oraclePrice,
                vars.borrowBalance,
                vars.sumBorrows
            );
        }
    
        if (vars.sumBorrows > 0) {
            _healthFactor = divExp(vars.sumLiquidityPlusThreshold, vars.sumBorrows);
        }

        return _healthFactor;
    }

    function tokenDecimals(address token) public view returns (uint256) {
        return
            token == EthAddressLib.ethAddress()
                ? 18
                : uint256(IERC20(token).decimals());
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
        address underlyingBorrowed = IFToken(fTokenBorrowed).underlying();
        address underlyingCollateral = IFToken(fTokenCollateral).underlying();
        require(!tokenConfigs[underlyingBorrowed].liquidateBorrowDisabled, "liquidateBorrow: liquidate borrow disabled");
        require(!tokenConfigs[underlyingCollateral].liquidateBorrowDisabled, "liquidateBorrow: liquidate colleteral disabled");

        uint256 hf = getHealthFactor(borrower);
        require(hf < 1e18, "HealthFactor > 1");
        userEnterMarket(IFToken(fTokenCollateral), liquidator);

        uint256 borrowBalance = IFToken(fTokenBorrowed).borrowBalanceStored(
            borrower
        );
        uint256 maxClose = mulScalarTruncate(closeFactor, borrowBalance);
        require(repayAmount <= maxClose, "Too much repay");
    }

    function _calcExchangeUnit(address fToken) internal view returns (uint256) {
        uint256 fTokenDecimals = uint256(IFToken(fToken).decimals());
        uint256 underlyingDecimals = tokenDecimals(IFToken(fToken).underlying());

        return 10**SafeMath.abs(fTokenDecimals, underlyingDecimals);
    }

    function calcExchangeUnit(address fToken) public view returns (uint256) {
        return allFtokenExchangeUnits[fToken];
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

    function balance(address token) external view returns (uint256) {
        if (token == EthAddressLib.ethAddress()) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }

    /**
    * @dev receive function enforces that the caller is a contract, to support flashloan transfers
    **/
    receive() external payable {
        //only contracts can send ETH to the bank controller
        require(address(msg.sender).isContract(), "Only contracts can send ether to the bank controller");
    }
}
