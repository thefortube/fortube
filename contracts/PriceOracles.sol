// SPDX-License-Identifier: MIT

pragma solidity 0.6.4;

import "./library/SafeMath.sol";
import "./library/EthAddressLib.sol";

// chainlink 价格合约接口
interface AggregatorInterface {
    function latestAnswer() external view returns (int256);
}

// 通用 oracle 接口
interface IUniversalOracle {
    function get(address token) external view returns (uint256, bool);
}

contract PriceOracles {
    using SafeMath for uint256;

    address public admin;

    address public proposedAdmin;

    // 通用的合约地址
    address public oracle;

    // 维护需要从chainlink取价格的token 地址 => chainlink 价格合约地址的映射
    mapping(address => address) public tokenChainlinkMap;

    function get(address token) external view returns (uint256, bool) {
        if (token == EthAddressLib.ethAddress() || tokenChainlinkMap[token] != address(0)) {
            // 如果是 eth 或者是需要从 chainlink 取价格的 token，读取 chainlink 的合约
            return getChainLinkPrice(token);
        } else {
            // 其他需要喂价的 token 从通用 oracle 中取价格
            IUniversalOracle _oracle = IUniversalOracle(oracle);
            return _oracle.get(token);
        }
    }

    // 存储 ETH/USD 交易对合约地址
    address public ethToUsdPrice;

    constructor() public {
        admin = msg.sender;
    }

    function setEthToUsdPrice(address _ethToUsdPrice) external onlyAdmin {
        ethToUsdPrice = _ethToUsdPrice;
    }

    // 设置通用 oracle 地址
    function setOracle(address _oracle) external onlyAdmin {
        oracle = _oracle;
    }

    //验证合约的操作是否被授权.
    modifier onlyAdmin {
        require(msg.sender == admin, "require admin");
        _;
    }

    function proposeNewAdmin(address admin_) external onlyAdmin {
        proposedAdmin = admin_;
    }

    function claimAdministration() external {
        require(msg.sender == proposedAdmin, "Not proposed admin.");
        admin = proposedAdmin;
        proposedAdmin = address(0);
    }

    function setTokenChainlinkMap(address token, address chainlink)
        external
        onlyAdmin
    {
        tokenChainlinkMap[token] = chainlink;
    }

    function getChainLinkPrice(address token)
        internal
        view
        returns (uint256, bool)
    {
        // 构造 chainlink 合约实例
        AggregatorInterface chainlinkContract = AggregatorInterface(
            ethToUsdPrice
        );
        // 获取 ETH/USD 交易对的价格，单位是 1e8
        int256 basePrice = chainlinkContract.latestAnswer();
        // 若要获取 ETH 的价格，则返回 1e8 * 1e10 = 1e18
        if (token == EthAddressLib.ethAddress()) {
            return (uint256(basePrice).mul(1e10), true);
        }
        // // 获取 token/ETH 交易对的价格（目前是 USDT 和 USDC ），单位是 1e18
        chainlinkContract = AggregatorInterface(tokenChainlinkMap[token]);
        int256 tokenPrice = chainlinkContract.latestAnswer();
        return (uint256(basePrice).mul(uint256(tokenPrice)).div(1e8), true);
    }
}
