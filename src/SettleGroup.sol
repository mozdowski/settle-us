// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

error NotOwner();
error NotGroupMember();
error NotInvited();
error InsufficientFunds();
error InsufficientFundsOrInactiveUser(string message);

contract SettleGroup {
    struct User {
        uint256[] transactionIds;
        string name;
        address addr;
        uint256 balance;
        bool isActive;
    }

    struct Transaction {
        uint256 id;
        address addr;
        uint256 amount;
        string description;
    }

    string groupName;
    address[] public usersAddresses;
    uint256 public immutable minEntryAmount;
    address immutable i_owner;

    uint public transactionCounter;

    mapping(address => bool) invitations;
    mapping(address => User) users;
    mapping(uint256 => Transaction) transactions;

    constructor(
        string memory _groupName,
        uint256 _minEntryAmountEth,
        address ownerAddress,
        string memory _ownerName
    ) payable {
        if (msg.value < _minEntryAmountEth) {
            revert InsufficientFunds();
        }

        groupName = _groupName;
        createActiveUser(_ownerName, ownerAddress, msg.value);
        i_owner = ownerAddress;
        minEntryAmount = _minEntryAmountEth;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert NotOwner();
        _;
    }

    modifier onlyMembers() {
        if (msg.sender != users[msg.sender].addr) revert NotGroupMember();
        _;
    }

    modifier onlyActiveMembers() {
        if (!users[msg.sender].isActive) revert NotGroupMember();
        _;
    }

    function inviteUser(address _userAddr) public onlyOwner {
        invitations[_userAddr] = true;
    }

    function join(string memory _username) public {
        if (!invitations[msg.sender]) {
            revert NotInvited();
        }
        createInactiveUser(_username, msg.sender);
    }

    function addFunds() public payable onlyMembers {
        User storage payer = users[msg.sender];

        if (!payer.isActive && msg.value < minEntryAmount) {
            revert InsufficientFundsOrInactiveUser(
                "Inactive user must pay the minimal entry amount"
            );
        }

        payer.balance += msg.value;

        if (!payer.isActive) {
            payer.isActive = true;
        }
    }

    function addTransaction(
        uint256 _amount,
        string memory _description
    ) public onlyActiveMembers {
        transactions[transactionCounter] = Transaction({
            id: transactionCounter,
            addr: msg.sender,
            amount: _amount,
            description: _description
        });

        uint256 numberOfUsers = usersAddresses.length;
        uint256 amountPerPerson = _amount / numberOfUsers;

        users[msg.sender].balance += _amount;

        for (uint i = 0; i < numberOfUsers; i++) {
            User storage user = users[usersAddresses[i]];
            user.transactionIds.push(transactionCounter);
            user.balance -= amountPerPerson;
        }

        transactionCounter++;
    }

    function settle() public onlyOwner {
        for (uint i = 0; i < usersAddresses.length; i++) {
            User storage user = users[usersAddresses[i]];
            (bool callSuccess, ) = payable(user.addr).call{value: user.balance}(
                ""
            );
            require(callSuccess, "Withdrawal failed");
            user.balance = 0;
        }
    }

    function createInactiveUser(string memory _name, address _addr) internal {
        User memory user = User(new uint256[](0), _name, _addr, 0, false);
        users[_addr] = user;

        usersAddresses.push(_addr);
    }

    function createActiveUser(
        string memory _name,
        address _addr,
        uint256 balance
    ) internal {
        User memory user = User(new uint256[](0), _name, _addr, balance, true);
        users[_addr] = user;

        usersAddresses.push(_addr);
    }

    function getGroupName() public view returns (string memory) {
        return groupName;
    }

    function getOwner()
        public
        view
        returns (address ownerAddress, string memory ownerName)
    {
        ownerAddress = i_owner;
        ownerName = users[i_owner].name;
    }

    function getMyDetails() public view onlyMembers returns (User memory) {
        return users[msg.sender];
    }

    function getTransactionDetailsByTransactionId(
        uint transactionId
    ) public view onlyActiveMembers returns (Transaction memory) {
        return transactions[transactionId];
    }

    fallback() external payable {
        addFunds();
    }

    receive() external payable {
        addFunds();
    }
}
