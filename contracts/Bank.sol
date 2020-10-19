// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity 0.6.4;

import "./library/SafeMath.sol";
import "./interface/IFToken.sol";
import "./interface/IBankController.sol";
import "./RewardType.sol";
import "./library/EthAddressLib.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";

// 入口合约
contract Bank is Initializable {
    using SafeMath for uint256;

    bool public paused;

    address public mulSig;

    //monitor event
    event MonitorEvent(bytes32 indexed funcName, bytes payload);
    modifier onlyFToken(address fToken) {
        require(
            controller.marketsContains(fToken) ||
                msg.sender == address(controller),
            "only supported ftoken or controller"
        );
        _;
    }

    function MonitorEventCallback(bytes32 funcName, bytes calldata payload)
        external
        onlyFToken(msg.sender)
    {
        emit MonitorEvent(funcName, payload);
    }

    // bank controller 实例
    IBankController public controller;

    address public admin;

    address public proposedAdmin;
    address public pauser;

    modifier onlyAdmin {
        require(msg.sender == admin, "OnlyAdmin");
        _;
    }

    modifier whenUnpaused {
        require(!paused, "System paused");
        _;
    }

    modifier onlyMulSig {
        require(msg.sender == mulSig, "require mulsig");
        _;
    }

    modifier onlySelf {
        require(msg.sender == address(this), "require self");
        _;
    }

    modifier onlyPauser {
        require(msg.sender == pauser, "require pauser");
        _;
    }

    // 初始化，只能初始化一次
    function initialize(address _controller, address _mulSig)
        public
        initializer
    {
        controller = IBankController(_controller);
        mulSig = _mulSig;
        paused = false;
        admin = msg.sender;
    }

    function setController(address _controller) public onlyAdmin {
        controller = IBankController(_controller);
    }

    function setPaused() public onlyPauser {
        paused = true;
    }

    function setUnpaused() public onlyPauser {
        paused = false;
    }

    function setPauser(address _pauser) public onlyAdmin {
        pauser = _pauser;
    }

    function proposeNewAdmin(address admin_) external onlyMulSig {
        proposedAdmin = admin_;
    }

    function claimAdministration() external {
        require(msg.sender == proposedAdmin, "Not proposed admin.");
        admin = proposedAdmin;
        proposedAdmin = address(0);
    }

    // 存钱返token
    modifier rewardFor(address usr, RewardType rewardType) {
        uint256 gasStart = gasleft();
        _;
        uint256 gasSpent = gasStart - gasleft();
        controller.rewardForByType(
            usr,
            gasSpent,
            tx.gasprice,
            uint256(rewardType)
        );
    }

    // 用户存款
    function deposit(address token, uint256 amount)
        public
        payable
        whenUnpaused
        rewardFor(msg.sender, RewardType.Deposit)
    {
        return this._deposit{value: msg.value}(token, amount, msg.sender);
    }

    // 用户存款
    function _deposit(
        address token,
        uint256 amount,
        address account
    ) external payable whenUnpaused onlySelf {
        IFToken fToken = IFToken(controller.getFTokeAddress(token));
        require(
            controller.marketsContains(address(fToken)),
            "unsupported token"
        );

        bytes memory flog = fToken.mint(account, amount);
        controller.transferIn{value: msg.value}(account, token, amount);

        fToken.addTotalCash(amount);

        emit MonitorEvent("Deposit", flog);
    }

    // 用户借款
    function borrow(address underlying, uint256 borrowAmount)
        public
        whenUnpaused
        rewardFor(msg.sender, RewardType.Borrow)
    {
        IFToken fToken = IFToken(controller.getFTokeAddress(underlying));
        require(
            controller.marketsContains(address(fToken)),
            "unsupported token"
        );

        bytes memory flog = fToken.borrow(msg.sender, borrowAmount);
        emit MonitorEvent("Borrow", flog);
    }

    // 用户取款 取 fToken 的数量
    function withdraw(address underlying, uint256 withdrawTokens)
        public
        whenUnpaused
        rewardFor(msg.sender, RewardType.Withdraw)
        returns (uint256)
    {
        IFToken fToken = IFToken(controller.getFTokeAddress(underlying));
        require(
            controller.marketsContains(address(fToken)),
            "unsupported token"
        );

        (uint256 amount, bytes memory flog) = fToken.withdraw(
            msg.sender,
            withdrawTokens,
            0
        );
        emit MonitorEvent("Withdraw", flog);
        return amount;
    }

    // 用户取款 取底层 token 的数量
    function withdrawUnderlying(address underlying, uint256 withdrawAmount)
        public
        whenUnpaused
        rewardFor(msg.sender, RewardType.Withdraw)
        returns (uint256)
    {
        IFToken fToken = IFToken(controller.getFTokeAddress(underlying));
        require(
            controller.marketsContains(address(fToken)),
            "unsupported token"
        );

        (uint256 amount, bytes memory flog) = fToken.withdraw(
            msg.sender,
            0,
            withdrawAmount
        );
        emit MonitorEvent("WithdrawUnderlying", flog);
        return amount;
    }

    // 用户还款
    function repay(address token, uint256 repayAmount)
        public
        payable
        whenUnpaused
        rewardFor(msg.sender, RewardType.Repay)
        returns (uint256)
    {
        return this._repay{value: msg.value}(token, repayAmount, msg.sender);
    }

    // 用户还款
    function _repay(
        address token,
        uint256 repayAmount,
        address account
    ) public payable whenUnpaused onlySelf returns (uint256) {
        IFToken fToken = IFToken(controller.getFTokeAddress(token));
        require(
            controller.marketsContains(address(fToken)),
            "unsupported token"
        );

        (uint256 actualRepayAmount, bytes memory flog) = fToken.repay(
            account,
            repayAmount
        );
        controller.transferIn{value: msg.value}(
            account,
            token,
            actualRepayAmount
        );

        fToken.addTotalCash(actualRepayAmount);

        emit MonitorEvent("Repay", flog);
        return actualRepayAmount;
    }

    // 用户清算
    function liquidateBorrow(
        address borrower,
        address underlyingBorrow,
        address underlyingCollateral,
        uint256 repayAmount
    ) public payable whenUnpaused {
        require(msg.sender != borrower, "Liquidator cannot be borrower");
        require(repayAmount > 0, "Liquidate amount not valid");

        IFToken fTokenBorrow = IFToken(
            controller.getFTokeAddress(underlyingBorrow)
        );
        IFToken fTokenCollateral = IFToken(
            controller.getFTokeAddress(underlyingCollateral)
        );
        bytes memory flog = fTokenBorrow.liquidateBorrow(
            msg.sender,
            borrower,
            repayAmount,
            address(fTokenCollateral)
        );
        controller.transferIn{value: msg.value}(
            msg.sender,
            underlyingBorrow,
            repayAmount
        );

        fTokenBorrow.addTotalCash(repayAmount);

        emit MonitorEvent("LiquidateBorrow", flog);
    }

    // 入金token in, 为还款和存款的组合
    //没有借款时，无需还款，有借款时，先还款，单独写一个进行入金，而不是直接调用mint和repay，原因在于在ETH存款时会有bug，msg.value会复用。
    function tokenIn(address token, uint256 amountIn)
        public
        payable
        whenUnpaused
        rewardFor(msg.sender, RewardType.TokenIn)
    {
        IFToken fToken = IFToken(controller.getFTokeAddress(token));
        require(
            controller.marketsContains(address(fToken)),
            "unsupported token"
        );

        //先进行冲账操作
        cancellingOut(token);
        uint256 curBorrowBalance = fToken.borrowBalanceCurrent(msg.sender);
        uint256 actualRepayAmount;

        //还清欠款
        if (amountIn == uint256(-1)) {
            require(curBorrowBalance > 0, "no debt to repay");
            if (token != EthAddressLib.ethAddress()) {
                require(
                    msg.value == 0,
                    "msg.value should be 0 for ERC20 repay"
                );
                actualRepayAmount = this._repay{value: 0}(
                    token,
                    amountIn,
                    msg.sender
                );
            } else {
                require(
                    msg.value >= curBorrowBalance,
                    "msg.value need great or equal than current debt"
                );
                actualRepayAmount = this._repay{value: curBorrowBalance}(
                    token,
                    amountIn,
                    msg.sender
                );
                if (msg.value > actualRepayAmount) {
                    (bool result, ) = msg.sender.call{
                        value: msg.value.sub(actualRepayAmount),
                        gas: controller.transferEthGasCost()
                    }("");
                    require(result, "Transfer of exceed ETH failed");
                }
            }

            emit MonitorEvent("TokenIn", abi.encode(token, actualRepayAmount));
        } else {
            if (curBorrowBalance > 0) {
                uint256 repayEthValue = SafeMath.min(
                    curBorrowBalance,
                    amountIn
                );
                if (token != EthAddressLib.ethAddress()) {
                    repayEthValue = 0;
                }
                actualRepayAmount = this._repay{value: repayEthValue}(
                    token,
                    SafeMath.min(curBorrowBalance, amountIn),
                    msg.sender
                );
            }

            // 还款数量有剩余，转为存款
            if (actualRepayAmount < amountIn) {
                uint256 exceedAmout = SafeMath.sub(amountIn, actualRepayAmount);
                if (token != EthAddressLib.ethAddress()) {
                    exceedAmout = 0;
                }
                this._deposit{value: exceedAmout}(
                    token,
                    SafeMath.sub(amountIn, actualRepayAmount),
                    msg.sender
                );
            }

            emit MonitorEvent("TokenIn", abi.encode(token, amountIn));
        }
    }

    // 出金token out, 为取款和借款的组合,
    // 取款如果该用户有对应的存款(有对应的ftoken)，完全可取出，剩余的部分采用借的逻辑,
    function tokenOut(address token, uint256 amountOut) external whenUnpaused {
        IFToken fToken = IFToken(controller.getFTokeAddress(token));
        require(
            controller.marketsContains(address(fToken)),
            "unsupported token"
        );

        //先进行冲账操作
        (bool strikeOk, bytes memory strikeLog) = fToken.cancellingOut(
            msg.sender
        );

        uint256 supplyAmount = 0;
        if (amountOut == uint256(-1)) {
            uint256 fBalance = fToken.balanceOf(msg.sender);
            require(fBalance > 0, "no asset to withdraw");
            supplyAmount = withdraw(token, fBalance);

            emit MonitorEvent("TokenOut", abi.encode(token, supplyAmount));
        } else {
            uint256 userSupplyBalance = fToken.calcBalanceOfUnderlying(
                msg.sender
            );
            if (userSupplyBalance > 0) {
                if (userSupplyBalance < amountOut) {
                    supplyAmount = withdraw(
                        token,
                        fToken.balanceOf(msg.sender)
                    );
                } else {
                    supplyAmount = withdrawUnderlying(
                        token,
                        SafeMath.min(userSupplyBalance, amountOut)
                    );
                }
            }

            if (supplyAmount < amountOut) {
                borrow(token, amountOut.sub(supplyAmount));
            }

            emit MonitorEvent("TokenOut", abi.encode(token, amountOut));
        }
    }

    function cancellingOut(address token) public whenUnpaused {
        IFToken fToken = IFToken(controller.getFTokeAddress(token));
        //先进行冲账操作
        (bool strikeOk, bytes memory strikeLog) = fToken.cancellingOut(
            msg.sender
        );
        if (strikeOk) {
            emit MonitorEvent("CancellingOut", strikeLog);
        }
    }
}
