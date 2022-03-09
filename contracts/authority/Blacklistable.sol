// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

import "./Owned.sol";

abstract contract Blacklistable is Owned {
    bytes32 public constant BLACKLISTED_ROLE = keccak256("BLACKLISTED_ROLE");

    function _Blacklistable() internal {
        _setRoleAdmin(BLACKLISTED_ROLE, OWNER_ROLE);
    }
    
    event Blacklisted(address indexed account);
    event UnBlacklisted(address indexed account);
    event DestroyFrom(address indexed account, uint256 amount);

    modifier notBlacklisted(address account) {
        require(!isBlacklisted(account), "account-is-blacklisted");
        _;
    }

    function isBlacklisted(address account) public view returns (bool) {
        return hasRole(BLACKLISTED_ROLE, account);
    }

    function blacklist(address account) external onlyOwner {
        grantRole(BLACKLISTED_ROLE, account);
        emit Blacklisted(account);
    }

    function unblacklist(address account) external onlyOwner {
        revokeRole(BLACKLISTED_ROLE, account);
        emit UnBlacklisted(account);
    }

    function destroyFrom(address account, uint256 amount) public onlyOwner {
        require(isBlacklisted(account), "account-not-blacklisted");
        _destroy(account, amount);
        emit DestroyFrom(account, amount);
    }

    function _destroy(address account, uint256 amount) internal virtual;

    uint256[50] private __gap;
}