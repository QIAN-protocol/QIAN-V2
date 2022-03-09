// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;
import "./Owned.sol";

contract Lockable is Owned {
    
    mapping(bytes4 => bool) public disabledList; 
    bool public globalDisable; 

    function _Lockable() internal {
    }

    modifier notLocked() {
        require(!globalDisable && !disabledList[msg.sig], "locked");
        _;
    }

    function enableListAccess(bytes4 sig) public onlyOwner {
        disabledList[sig] = false;
    }

    function disableListAccess(bytes4 sig) public onlyOwner {
        disabledList[sig] = true;
    }

    function enableGlobalAccess() public onlyOwner {
        globalDisable = false;
    }

    function disableGlobalAccess() public onlyOwner {
        globalDisable = true;
    }

    uint256[50] private __gap;
}
