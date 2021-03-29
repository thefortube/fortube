// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity 0.6.4;

import "./library/SafeMath.sol";
import "./interface/IFToken.sol";
import "./interface/IBankController.sol";
import "./RewardType.sol";
import "./library/EthAddressLib.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "./interface/IFlashLoanReceiver.sol";

// Contract Entry
contract Bank is Initializable {
    using SafeMath for uint256;

    bool public paused;

    address public mulSig;

    //monitor event
    event MonitorEvent(bytes32 indexed funcName, bytes payload);
    event FlashLoan(
        address indexed receiver,
        address indexed token,
        uint256 amount,
        uint256 fee
    );

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

    // bank controller instance
    IBankController public controller;

    address public admin;

    address public proposedAdmin;
    address public pauser;

    bool private loaning;
    modifier nonSelfLoan() {
        require(!loaning, "re-loaning");
        loaning = true;
        _;
        loaning = false;
    }

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

    // Initialization, can only be initialized once
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

    // User deposit
    function deposit(address token, uint256 amount)
        public
        payable
        whenUnpaused
    {
        return this._deposit{value: msg.value}(token, amount, msg.sender);
    }

    // User deposit
    function _deposit(
        address token,
        uint256 amount,
        address account
    ) external payable whenUnpaused onlySelf nonSelfLoan {
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

    // User borrow
    function borrow(address underlying, uint256 borrowAmount)
        public
        whenUnpaused
        nonSelfLoan
    {
        IFToken fToken = IFToken(controller.getFTokeAddress(underlying));
        require(
            controller.marketsContains(address(fToken)),
            "unsupported token"
        );

        bytes memory flog = fToken.borrow(msg.sender, borrowAmount);
        emit MonitorEvent("Borrow", flog);
    }

    // The user specifies a certain amount of ftoken and retrieves the underlying assets
    function withdraw(address underlying, uint256 withdrawTokens)
        public
        whenUnpaused
        nonSelfLoan
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

    // The user retrieves a certain amount of underlying assets
    function withdrawUnderlying(address underlying, uint256 withdrawAmount)
        public
        whenUnpaused
        nonSelfLoan
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

    // User repayment
    function repay(address token, uint256 repayAmount)
        public
        payable
        whenUnpaused
        returns (uint256)
    {
        return this._repay{value: msg.value}(token, repayAmount, msg.sender);
    }

    // User repayment
    function _repay(
        address token,
        uint256 repayAmount,
        address account
    ) public payable whenUnpaused onlySelf nonSelfLoan returns (uint256) {
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

    // User Liquidate
    function liquidateBorrow(
        address borrower,
        address underlyingBorrow,
        address underlyingCollateral,
        uint256 repayAmount
    ) public payable whenUnpaused nonSelfLoan {
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

    // tokenIn, is a combination of repayment and deposit
    function tokenIn(address token, uint256 amountIn)
        public
        payable
        whenUnpaused
    {
        IFToken fToken = IFToken(controller.getFTokeAddress(token));
        require(
            controller.marketsContains(address(fToken)),
            "unsupported token"
        );
    
        cancellingOut(token);
        uint256 curBorrowBalance = fToken.borrowBalanceCurrent(msg.sender);
        uint256 actualRepayAmount;

        //Pay off debts
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

            // If the repayment amount is left, it will be converted to deposit
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

    // tokenOut, is a combination of withdrawal and borrowing
    function tokenOut(address token, uint256 amountOut) external whenUnpaused {
        IFToken fToken = IFToken(controller.getFTokeAddress(token));
        require(
            controller.marketsContains(address(fToken)),
            "unsupported token"
        );

        cancellingOut(token);

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
                        amountOut
                    );
                }
            }

            if (supplyAmount < amountOut) {
                borrow(token, amountOut.sub(supplyAmount));
            }

            emit MonitorEvent("TokenOut", abi.encode(token, amountOut));
        }
    }

    function cancellingOut(address token) public whenUnpaused nonSelfLoan {
        IFToken fToken = IFToken(controller.getFTokeAddress(token));
        (bool strikeOk, bytes memory strikeLog) = fToken.cancellingOut(
            msg.sender
        );
        if (strikeOk) {
            emit MonitorEvent("CancellingOut", strikeLog);
        }
    }

    function flashloan(
        address receiver,
        address token,
        uint256 amount,
        bytes memory params
    ) public whenUnpaused nonSelfLoan {
        uint256 balanceBefore = controller.balance(token);
        require(amount > 0 && amount <= balanceBefore, "insufficient flashloan liquidity");

        uint256 fee = amount.mul(controller.flashloanFeeBips()).div(10000);
        address payable _receiver = address(uint160(receiver));

        controller.transferFlashloanAsset(token, _receiver, amount); 
        IFlashLoanReceiver(_receiver).executeOperation(token, amount, fee, params);

        uint256 balanceAfter = controller.balance(token);
        require(balanceAfter >= balanceBefore.add(fee), "invalid flashloan payback amount");

        address payable vault = address(uint160(controller.flashloanVault()));
        controller.transferFlashloanAsset(token, vault, fee);

        emit FlashLoan(receiver, token, amount, fee);
    }
}
