// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

import "./Owned.sol";

abstract contract Mintable is Owned {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    event AddedMinter(address indexed account);
    event RemovedMinter(address indexed account);
    event RenouncedMinter(address indexed account);

    function _Mintable() internal {
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    modifier onlyMinter() {
        require(isMinter(msg.sender), "account-is-not-minter");
        _;
    }

    function isMinter(address account) public view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    function addMinter(address account) public onlyAdmin {
        grantRole(MINTER_ROLE, account);
        emit AddedMinter(account);
    }

    function removeMinter(address account) public onlyAdmin {
        revokeRole(MINTER_ROLE, account);
        emit RemovedMinter(account);
    }
    
    function renounceMinter() public {
        renounceRole(MINTER_ROLE, msg.sender);
        emit RenouncedMinter(msg.sender);
    }

    uint256[50] private __gap;
}
