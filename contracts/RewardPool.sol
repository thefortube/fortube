pragma experimental ABIEncoderV2;
pragma solidity 0.6.4;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "./interface/IERC20.sol";

contract RewardPool is Initializable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public theForceToken; // 奖励的FOR token地址
    address public bankController;//允许bankController从此合约中划账
    address public admin;

    modifier onlyAdmin {
        require(msg.sender == admin, "OnlyAdmin");
        _;
    }

    modifier onlyBankController {
        require(msg.sender == bankController, "require bankcontroller");
        _;
    }

    function initialize(address _theForceToken, address _bankController)
        public
        initializer
    {
        theForceToken = _theForceToken;
        bankController = _bankController;
        admin = msg.sender;
    }

    function deposit(uint256 amount) external {
        address who = msg.sender;
        require(
            IERC20(theForceToken).allowance(who, address(this)) >= amount,
            "insufficient allowance to deposit"
        );
        require(
            IERC20(theForceToken).balanceOf(who) >= amount,
            "insufficient balance to deposit"
        );
        IERC20(theForceToken).safeTransferFrom(who, address(this), amount);
    }

    function withdraw(uint256 amount) external onlyAdmin {
        IERC20(theForceToken).safeTransfer(msg.sender, amount);
    }

    function withdraw() external onlyAdmin {
        IERC20(theForceToken).safeTransfer(msg.sender, IERC20(theForceToken).balanceOf(address(this)));
    }

    function setTheForceToken(address _theForceToken) external onlyAdmin {
        theForceToken = _theForceToken;
    }

    function setBankController(address _bankController) external onlyAdmin {
        bankController = _bankController;
    }
    
    function reward(address who, uint256 amount) external onlyBankController {
        IERC20(theForceToken).safeTransfer(who, amount);
    }
}
