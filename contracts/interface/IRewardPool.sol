pragma experimental ABIEncoderV2;
pragma solidity 0.6.4;

// reward token pool interface (FOR)
interface IRewardPool {
    function theForceToken() external view returns (address);
    function bankController() external view returns (address);
    function admin() external view returns (address);

    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;
    function withdraw() external;

    function setTheForceToken(address _theForceToken) external;
    function setBankController(address _bankController) external;

    function reward(address who, uint256 amount) external;
}
