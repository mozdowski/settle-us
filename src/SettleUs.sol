// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./SettleGroup.sol";

contract SettleUs {
    address[] groups;
    mapping(address => address[]) s_userGroups;
    mapping(address => address[]) s_userInvitations;

    function createNewGroup(
        string memory _groupName,
        uint256 _minEntryAmountEth,
        string memory _ownerName
    ) public payable returns (address) {
        if (msg.value < _minEntryAmountEth) {
            revert InsufficientFunds();
        }

        SettleGroup group = new SettleGroup{value: msg.value}(
            _groupName,
            _minEntryAmountEth,
            msg.sender,
            _ownerName
        );

        address createdGroupAddr = address(group);
        s_userGroups[msg.sender].push(createdGroupAddr);

        return createdGroupAddr;
    }

    function getMyGroups() public view returns (address[] memory) {
        return s_userGroups[msg.sender];
    }

    function getMyGroupInvitations() public view returns (address[] memory) {
        return s_userInvitations[msg.sender];
    }
}
