// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {DeploySettleUs} from "../../script/DeploySettleUs.s.sol";
import {SettleUs} from "../../src/SettleUs.sol";
import {SettleGroup} from "../../src/SettleUs.sol";

contract SettleUsTest is StdCheats, Test {
    SettleUs public settleUs;
    SettleGroup public settleGroup;

    string public constant GROUP_NAME = "testGroup";
    string public constant OWNER_NAME = "testOwner";

    address public constant USER = address(1);

    function setUp() external {
        DeploySettleUs deployer = new DeploySettleUs();
        (settleUs) = deployer.run();
        setTestGroup();
    }

    function testGroupIsCreated() public {
        vm.startPrank(USER);
        assertEq(settleUs.getMyGroups().length, 1);
        vm.stopPrank();
    }

    function testOwnerAdded() public {
        (address ownerAddress, string memory ownerName) = settleGroup
            .getOwner();
        assertEq(ownerAddress, USER);
        assertEq(ownerName, OWNER_NAME);
    }

    function testGroupNameIsSet() public {
        string memory groupName = settleGroup.getGroupName();
        assertEq(groupName, GROUP_NAME);
    }

    function setTestGroup() private {
        vm.startPrank(USER);
        address testGroupAddress = settleUs.createNewGroup(
            GROUP_NAME,
            1 ether,
            OWNER_NAME
        );
        settleGroup = SettleGroup(payable(testGroupAddress));
        vm.stopPrank();
    }
}
