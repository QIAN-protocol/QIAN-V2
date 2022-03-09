// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

import "../lib/openzeppelin-contracts/AccessControl.sol";

contract Admined is AccessControl {
    //constructor
    function _Admined(address admin) internal {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "Restricted to admins");
        _;
    }

    function isAdmin(address account) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    function getAdminCount() public view returns(uint256) {
        return getRoleMemberCount(DEFAULT_ADMIN_ROLE);
    }

    function addAdmin(address account) public virtual onlyAdmin {
        grantRole(DEFAULT_ADMIN_ROLE, account);
    }

    function renounceAdmin() public virtual {
        renounceRole(DEFAULT_ADMIN_ROLE, msg.sender);
        require(
            getRoleMemberCount(DEFAULT_ADMIN_ROLE) >= 1,
            "At least one admin required"
        );
    }

    uint256[50] private __gap;
}
