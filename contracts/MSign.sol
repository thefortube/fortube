pragma solidity 0.6.4;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";

contract Msign {
    using EnumerableSet for EnumerableSet.AddressSet;

    event Activate(address indexed sender, bytes32 id);
    event Execute(address indexed sender, bytes32 id);
    event Sign(address indexed sender, bytes32 id);
    event Enable(address indexed sender, address indexed account);
    event Disable(address indexed sender, address indexed account);

    struct proposal_t {
        address code;
        bytes   data;
        uint256 done;
        mapping(address => uint256) signers;
    }

    mapping(bytes32 => proposal_t) public proposals;
    uint256 private _weight;
    EnumerableSet.AddressSet private _signers;

    constructor(
        uint256 _length,
        address[] memory _accounts
    ) public {
        require(_length >= 1, "Msign.Length not valid");
        require(_length == _accounts.length, "Msign.Args fault");
        for (uint256 i = 0; i < _length; ++i) {
            require(_signers.add(_accounts[i]), "Msign.Duplicate signer");
        }
    }

    //single sign auth
    modifier ssignauth() {
        require(_signers.contains(msg.sender), "Msign.Invalid signer");
        _;
    }

    //multi sign auth
    modifier msignauth(bytes32 id) {
        require(mulsignweight(id) >= threshold(), "Msign.Threshold unreached");
        _;
    }

    modifier auth() {
        require(msg.sender == address(this));
        _;
    }

    function gethash(address code, bytes memory data)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(code, data));
    }

    function activate(address code, bytes memory data)
        public
        ssignauth
        returns (bytes32)
    {
        require(code != address(0), "Msign.Invalid args");
        require(data.length >= 4, "Msign.Invalid args");
        bytes32 _hash = gethash(code, data);
        proposals[_hash].code = code;
        proposals[_hash].data = data;
        emit Activate(msg.sender, _hash);
        return _hash;
    }

    function execute(bytes32 id)
        public
        msignauth(id)
        returns (bool success, bytes memory result)
    {
        require(proposals[id].done == 0, "Msign.Proposal has been executed");
        proposals[id].done = 1;
        (success, result) = proposals[id].code.call(proposals[id].data);
        require(success, "Msign.Execute fail");
        emit Execute(msg.sender, id);
    }

    function sign(bytes32 id) public ssignauth {
        require(proposals[id].signers[msg.sender] == 0, "Msign.Duplicate sign");
        proposals[id].signers[msg.sender] = 1;
        emit Sign(msg.sender, id);
    }

    function enable(address account) public auth {
        require(_signers.add(account), "Msign.Duplicate signer");
        emit Enable(msg.sender, account);
    }

    function disable(address account) public auth {
        require(_signers.remove(account), "Msign.Disable nonexist");
        require(_signers.length() >= 1, "Msign.Invalid set");
        emit Disable(msg.sender, account);
    }

    function mulsignweight(bytes32 id) public view returns (uint256) {
        uint256 _weights = 0;
        for (uint256 i = 0; i < _signers.length(); ++i) {
            _weights += proposals[id].signers[_signers.at(i)];
        }
        return _weights;
    }

    function threshold() public view returns (uint256) {
        return (_signers.length() / 2) + 1;
    }

    function signers() public view returns (address[] memory) {
        address[] memory values = new address[](_signers.length());
        for (uint256 i = 0; i < _signers.length(); ++i) {
            values[i] = _signers.at(i);
        }
        return values;
    }

    function signable(address signer) public view returns (bool) {
        return _signers.contains(signer);
    }
}
