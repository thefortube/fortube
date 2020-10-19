/**
 *Submitted for verification at Etherscan.io on 2020-06-02
 */

pragma experimental ABIEncoderV2;
pragma solidity 0.6.4;

contract MockOracle {

    struct Price {
        uint256 price;
        uint256 expiration;
    }

    mapping(address => Price) public prices;

    function getExpiration(address token) external view returns (uint256) {
        return prices[token].expiration;
    }

    function getPrice(address token) external view returns (uint256) {
        return prices[token].price;
    }

    function get(address token) external view returns (uint256, bool) {
        return (prices[token].price, valid(token));
    }

    function valid(address token) public view returns (bool) {
        return now < prices[token].expiration;
    }

    // 设置价格为 @val, 保持有效时间为 @exp second.
    function set(
        address token,
        uint256 val
    ) public {
        prices[token].price = val;
        prices[token].expiration = now + 100 days;
    }

    //批量设置，减少gas使用
    function batchSet(
        address[] calldata tokens,
        uint256[] calldata vals,
        uint256[] calldata exps
    ) external {
        uint256 nToken = tokens.length;
        require(
            nToken == vals.length && vals.length == exps.length,
            "invalid array length"
        );
        for (uint256 i = 0; i < nToken; ++i) {
            prices[tokens[i]].price = vals[i];
            prices[tokens[i]].expiration = now + exps[i];
        }
    }
}
