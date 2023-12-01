// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./SettleGroup.sol";

contract SettleUs {
    address[] groups;
    mapping(address => address[]) userGroups;
    mapping(address => address[]) userInvitations;

    function createNewGroup(
        string memory _groupName,
        uint256 _minEntryAmountEth,
        string memory _ownerName
    ) public returns (address) {
        SettleGroup group = new SettleGroup(
            _groupName,
            _minEntryAmountEth,
            _ownerName
        );

        address createdGroupAddr = address(group);
        userGroups[msg.sender].push(createdGroupAddr);

        return createdGroupAddr;
    }

    function getMyGroups() public view returns (address[] memory) {
        return userGroups[msg.sender];
    }

    function getMyGroupInvitations() public view returns (address[] memory) {
        return userInvitations[msg.sender];
    }
}
