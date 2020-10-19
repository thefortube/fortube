pragma solidity ^0.6.0;

import "../library/SafeMath.sol";

contract MockUSDT {
    using SafeMath for uint256;

    string public name;
    string public symbol;
    uint256 public decimals;

    uint256 public _totalSupply;

    mapping(address => mapping(address => uint256)) private _allowed;
    mapping(address => uint256) _balances;

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    constructor() public {
        name = "USDT";
        symbol = "USDT";

        decimals = 6;
        _totalSupply = 1000000000;

        _balances[msg.sender] = _totalSupply;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address tokenOwner)
        public
        view
        returns (uint256 balance)
    {
        return _balances[tokenOwner];
    }

    function transfer(address to, uint256 value) public returns (bool) {
        require(value <= _balances[msg.sender]);

        require(to != address(0));

        _balances[msg.sender] = _balances[msg.sender].sub(value);

        _balances[to] = _balances[to].add(value);

        emit Transfer(msg.sender, to, value);

        return true;
    }

    function allowance(address tokenOwner, address spender)
        public
        view
        returns (uint256 remaining)
    {
        return _allowed[tokenOwner][spender];
    }

    function approve(address spender, uint256 tokens)
        public
        returns (bool success)
    {
        _allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokens
    ) public returns (bool success) {
        _balances[from] = _balances[from].sub(tokens);
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(tokens);
        _balances[to] = _balances[to].add(tokens);
        emit Transfer(from, to, tokens);
        return true;
    }
}
