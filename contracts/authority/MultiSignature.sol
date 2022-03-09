// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import "../lib/openzeppelin-contracts/EnumerableSet.sol";

contract MultiSignature {
    using EnumerableSet for EnumerableSet.AddressSet;

    event Activate(address indexed sender, bytes32 indexed id);
    event Execute(address indexed sender, bytes32 indexed id);
    event Sign(address indexed sender, bytes32 indexed id);
    event Cancel(address indexed sender, bytes32 indexed id);
    event AddedAdmin(address indexed sender, address indexed account);
    event RemovedAdmin(address indexed sender, address indexed account);
    event SetThreshold(address indexed sender, uint256 newThreshold);

    struct Proposal {
        address author;
        address code;
        bytes data;
        bool pending;
        mapping(address => uint256) signers;
    }

    mapping(bytes32 => Proposal) public proposals;
    EnumerableSet.AddressSet private _accounts;
    uint256 public threshold;

    constructor(uint256 newThreshold, address[] memory newAccounts) public {
        uint256 count = newAccounts.length;
        require(count >= 1, "invalid-accounts-length");
        require(newThreshold >= 1 && newThreshold <= count, "invalid-threshold");
        threshold = newThreshold;
        for (uint256 i = 0; i < count; ++i)
            require(_accounts.add(newAccounts[i]), "account-duplication");
    }

    modifier onlyMultiSignature() {
        require(msg.sender == address(this), "multi-signature-permission-denied");
        _;
    }

    modifier onlyAdmin() {
        require(_accounts.contains(msg.sender), "admin-permission-denied");
        _;
    }

    function activate(address code, bytes memory data) public onlyAdmin {
        require(code != address(0), "activate-with-invalid-code");
        require(data.length >= 4, "activate-with-invalid-data");
        bytes32 id = getHash(code, data);
        if (proposals[id].pending) _clean(id);
        proposals[id].author = msg.sender;
        proposals[id].code = code;
        proposals[id].data = data;
        proposals[id].pending = true;
        emit Activate(msg.sender, id);
    }

    function execute(bytes32 id) public returns (bool success, bytes memory result)
    {
        require(proposals[id].pending, "proposal-not-activated");
        require(getWeight(id) >= threshold, "insufficient-weight");
        (success, result) = proposals[id].code.call(proposals[id].data);
        require(success, "proposal-execute-failed");
        _clean(id);
        emit Execute(msg.sender, id);
    }

    function sign(bytes32 id) public onlyAdmin {
        require(proposals[id].pending, "proposal-not-activated");
        require(proposals[id].signers[msg.sender] == 0, "signature-duplication");
        proposals[id].signers[msg.sender] = 1;
        emit Sign(msg.sender, id);
    }

    function cancel(bytes32 id) public {
        require(proposals[id].author == msg.sender, "author-permission-denied");
        _clean(id);
        emit Cancel(msg.sender, id);
    }

    function addAdmin(address account) public onlyMultiSignature {
        require(_accounts.add(account), "account-duplication");
        emit AddedAdmin(msg.sender, account);
    }

    function removeAdmin(address account) public onlyMultiSignature {
        require(_accounts.remove(account), "account-not-exist");
        require(_accounts.length() >= threshold, "account-must-morethan-threshold");
        emit RemovedAdmin(msg.sender, account);
    }

    function setThreshold(uint256 newThreshold) public onlyMultiSignature {
        require(newThreshold >= 1 && newThreshold <= _accounts.length(), "invalid-threshold");
        threshold = newThreshold;
        emit SetThreshold(msg.sender, newThreshold);
    }

    function getWeight(bytes32 id) public view returns (uint256) {
        uint256 weights = 0;
        for (uint256 i = 0; i < _accounts.length(); ++i)
            weights += proposals[id].signers[_accounts.at(i)];
        return weights;
    }

    function getHash(address code, bytes memory data) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(code, data));
    }

    function getAdmins() public view returns (address[] memory) {
        address[] memory admines = new address[](_accounts.length());
        for (uint256 i = 0; i < _accounts.length(); ++i)
            admines[i] = _accounts.at(i);
        return admines;
    }

    function isAdmin(address signer) public view returns (bool) {
        return _accounts.contains(signer);
    }

    function _clean(bytes32 id) internal {
        for (uint256 i = 0; i < _accounts.length(); ++i)
            proposals[id].signers[_accounts.at(i)] = 0;
        delete proposals[id];
    }
}
