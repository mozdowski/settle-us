// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {DeploySettleUs} from "../../script/DeploySettleUs.s.sol";
import {SettleUs} from "../../src/SettleUs.sol";
import {SettleGroup, NotOwner, NotInvited, NotGroupMember, InsufficientFundsOrInactiveUser} from "../../src/SettleUs.sol";

contract SettleUsTest is StdCheats, Test {
    SettleUs public settleUs;
    SettleGroup public settleGroup;

    uint256 public constant STARTING_USER_BALANCE = 5 ether;
    uint256 public constant MIN_ENTRY_AMOUNT = 2 ether;

    string public constant GROUP_NAME = "testGroup";
    string public constant OWNER_NAME = "testOwner";
    string public constant MEMBER_NAME = "testMember";

    address public constant OWNER = address(1);
    address public constant MEMBER = address(2);

    function setUp() external {
        DeploySettleUs deployer = new DeploySettleUs();
        (settleUs) = deployer.run();

        vm.deal(OWNER, STARTING_USER_BALANCE);
        vm.deal(MEMBER, STARTING_USER_BALANCE);

        setTestGroup();
    }

    function testGroupIsCreated() public {
        vm.startPrank(OWNER);
        assertEq(settleUs.getMyGroups().length, 1);
        vm.stopPrank();
    }

    function testOwnerAdded() public {
        (address ownerAddress, string memory ownerName) = settleGroup
            .getOwner();
        assertEq(ownerAddress, OWNER);
        assertEq(ownerName, OWNER_NAME);
    }

    function testGroupNameIsSet() public {
        string memory groupName = settleGroup.getGroupName();
        assertEq(groupName, GROUP_NAME);
    }

    function testInvitationToGroupIsSeenByInvitedUser() public {
        inviteMember();

        vm.startPrank(MEMBER);
        address testGroupInvitation = settleUs.getMyGroupInvitations()[0];
        vm.stopPrank();

        assertEq(address(settleGroup), testGroupInvitation);
    }

    function testOnlyOwnerCanInviteToGroup() public {
        vm.startPrank(MEMBER);
        vm.expectRevert(NotOwner.selector);
        settleGroup.inviteUser(MEMBER);
        vm.stopPrank();
    }

    function testJoiningToGroupWithInvitationCreatesNewGroupMember() public {
        inviteMember();

        vm.startPrank(MEMBER);
        settleGroup.join(MEMBER_NAME);
        assertEq(MEMBER, settleGroup.getMyDetails().addr);
        vm.stopPrank();
    }

    function testJoiningGroupWithoutInvitationReturnsError() public {
        vm.startPrank(MEMBER);
        vm.expectRevert(NotInvited.selector);
        settleGroup.join(MEMBER_NAME);
        vm.stopPrank();
    }

    function testAddingFoundsByMemberIncreasesBalance() public {
        inviteMember();
        acceptInvitation();

        vm.startPrank(MEMBER);
        uint256 beforeFundingAmount = settleGroup.getMyDetails().balance;
        settleGroup.addFunds{value: MIN_ENTRY_AMOUNT}();
        uint256 afterFundingAmount = settleGroup.getMyDetails().balance;
        vm.stopPrank();

        uint256 beforeAmountIncreasedByFundedAmount = beforeFundingAmount +
            MIN_ENTRY_AMOUNT;

        assertEq(afterFundingAmount, beforeAmountIncreasedByFundedAmount);
    }

    function testAddingNewFoundsByMemberActivatesUser() public {
        inviteMember();
        acceptInvitation();

        vm.startPrank(MEMBER);
        settleGroup.addFunds{value: MIN_ENTRY_AMOUNT}();
        bool userIsActive = settleGroup.getMyDetails().isActive;
        vm.stopPrank();

        assertTrue(userIsActive);
    }

    function testAddingFoundsByNonMemberReturnsError() public {
        vm.startPrank(MEMBER);
        vm.expectRevert(NotGroupMember.selector);
        settleGroup.addFunds{value: MIN_ENTRY_AMOUNT}();
        vm.stopPrank();
    }

    function testAddingFoundsWithNotEnoughAmountReturnsError() public {
        inviteMember();
        acceptInvitation();

        vm.startPrank(MEMBER);
        vm.expectRevert(
            abi.encodeWithSelector(
                InsufficientFundsOrInactiveUser.selector,
                "Inactive user must pay the minimal entry amount"
            )
        );
        settleGroup.addFunds{value: MIN_ENTRY_AMOUNT / 2}();
        vm.stopPrank();
    }

    function testAddNewValidTransactionToTransactions() public {
        uint256 testTransactionAmount = 1 ether;
        string memory description = "Some transaction!";

        inviteMember();
        acceptInvitation();

        vm.startPrank(MEMBER);

        uint initialTransactionCounter = settleGroup.transactionCounter();

        SettleGroup.Transaction memory testTransaction = SettleGroup
            .Transaction({
                id: initialTransactionCounter,
                addr: MEMBER,
                amount: testTransactionAmount,
                description: description
            });
        bytes memory encodedTestTransaction = abi.encode(testTransaction);

        settleGroup.addFunds{value: MIN_ENTRY_AMOUNT}();
        settleGroup.addTransaction(testTransactionAmount, description);

        SettleGroup.Transaction memory addedTransaction = settleGroup
            .getTransactionDetailsByTransactionId(initialTransactionCounter);
        bytes memory encodedAddedTransaction = abi.encode(addedTransaction);
        uint newTransactionCounterValue = settleGroup.transactionCounter();
        vm.stopPrank();

        assertEq(newTransactionCounterValue, initialTransactionCounter + 1);
        assertEq(encodedTestTransaction, encodedAddedTransaction);
    }

    function testAddingValidTransactionAddsTransactionIdToUserTransactionList()
        public
    {
        uint256 testTransactionAmount = 1 ether;
        string memory description = "Some transaction!";

        inviteMember();
        acceptInvitation();

        vm.startPrank(MEMBER);

        uint initialTransactionCounter = settleGroup.transactionCounter();

        settleGroup.addFunds{value: MIN_ENTRY_AMOUNT}();
        settleGroup.addTransaction(testTransactionAmount, description);

        uint transactionId = settleGroup.getMyDetails().transactionIds[0];
        vm.stopPrank();

        assertEq(transactionId, initialTransactionCounter);
    }

    function testTransactionUpdatesUserBalancesEquallyByAmountPerPerson()
        public
    {
        uint256 testTransactionAmount = 1 ether;
        uint256 amountPerPerson = testTransactionAmount / 2;
        string memory description = "Some transaction!";

        inviteMember();
        acceptInvitation();

        vm.startPrank(OWNER);
        uint ownerBalaceBefore = settleGroup.getMyDetails().balance;
        vm.stopPrank();

        vm.startPrank(MEMBER);

        settleGroup.addFunds{value: MIN_ENTRY_AMOUNT}();
        uint memberBalaceBefore = settleGroup.getMyDetails().balance;

        settleGroup.addTransaction(testTransactionAmount, description);

        uint memberBalaceAfter = settleGroup.getMyDetails().balance;
        vm.stopPrank();

        vm.startPrank(OWNER);
        uint ownerBalaceAfter = settleGroup.getMyDetails().balance;
        vm.stopPrank();

        assertEq(
            memberBalaceAfter,
            memberBalaceBefore + testTransactionAmount - amountPerPerson
        );
        assertEq(ownerBalaceAfter, ownerBalaceBefore - amountPerPerson);
    }

    function testOnlyActiveMembersCanAddTransactions() public {
        uint256 testTransactionAmount = 1 ether;
        string memory description = "Some transaction!";

        inviteMember();
        acceptInvitation();

        vm.startPrank(MEMBER);
        vm.expectRevert(NotGroupMember.selector);
        settleGroup.addTransaction(testTransactionAmount, description);
        vm.stopPrank();
    }

    function testOnlyOwnerCanSettleGroup() public {
        vm.startPrank(MEMBER);
        vm.expectRevert(NotOwner.selector);
        settleGroup.settle();
        vm.stopPrank();
    }

    function testSettlingResetsUsersBalance() public {
        uint256 testTransactionAmount = 1 ether;
        string memory description = "Some transaction!";

        inviteMember();
        acceptInvitation();

        vm.startPrank(MEMBER);
        settleGroup.addFunds{value: MIN_ENTRY_AMOUNT}();
        settleGroup.addTransaction(testTransactionAmount, description);
        vm.stopPrank();

        vm.startPrank(OWNER);
        settleGroup.settle();
        uint256 ownerAfterBalance = settleGroup.getMyDetails().balance;
        vm.stopPrank();

        vm.startPrank(MEMBER);
        uint256 memberAfterBalance = settleGroup.getMyDetails().balance;
        vm.stopPrank();

        assertEq(ownerAfterBalance, 0);
        assertEq(memberAfterBalance, 0);
    }

    function testSettlingSendsRemainingBalanceToUserAddress() public {
        uint256 testTransactionAmount = 1 ether;
        string memory description = "Some transaction!";

        uint256 amountPerPerson = testTransactionAmount / 2;
        uint256 expectedMemberBalanceAfterTransaction = STARTING_USER_BALANCE +
            amountPerPerson;

        inviteMember();
        acceptInvitation();

        vm.startPrank(MEMBER);
        settleGroup.addFunds{value: MIN_ENTRY_AMOUNT}();
        settleGroup.addTransaction(testTransactionAmount, description);
        vm.stopPrank();

        vm.startPrank(OWNER);
        settleGroup.settle();
        vm.stopPrank();

        assertEq(MEMBER.balance, expectedMemberBalanceAfterTransaction);
    }

    function setTestGroup() private {
        vm.startPrank(OWNER);
        address testGroupAddress = settleUs.createNewGroup{
            value: MIN_ENTRY_AMOUNT
        }(GROUP_NAME, MIN_ENTRY_AMOUNT, OWNER_NAME);
        settleGroup = SettleGroup(payable(testGroupAddress));
        vm.stopPrank();
    }

    function inviteMember() private {
        vm.startPrank(OWNER);
        settleGroup.inviteUser(MEMBER);
        vm.stopPrank();
    }

    function acceptInvitation() private {
        vm.startPrank(MEMBER);
        settleGroup.join(MEMBER_NAME);
        vm.stopPrank();
    }
}
