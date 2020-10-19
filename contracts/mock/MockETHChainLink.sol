pragma solidity 0.6.4;

contract MockETHChainLink {
    function latestAnswer() public view returns (int256) {
        return 39872000000;
    }
}