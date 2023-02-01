// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Counters.sol";
 

contract MultiSigWallet {
    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public numConfirmationsRequired;

    struct Transaction {
        address target;
        uint value;
        string func ;
        bytes data ; 
        string note;
        bool executed;
        uint numConfirmations;
    }

    // mapping from tx index => owner => bool
    mapping(uint => mapping(address => bool)) public isConfirmed;
    using Counters for Counters.Counter;
    Counters.Counter private Txindex;

    //mapping transaction to transaction index 
    mapping(uint => Transaction) public transactions;

    // Transaction[] public transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    // modifier txExists(uint _txIndex) {
    //     require(_txIndex < transactions.length, "tx does not exist");
    //     _;
    // }
    
      modifier txExists(uint _txIndex) {
        require(transactions[_txIndex].target==address(0), "tx does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
        require(_owners.length > 0, "owners required");
        require(
            _numConfirmationsRequired > 0 &&
                _numConfirmationsRequired <= _owners.length,
            "invalid number of required confirmations"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(
        address _target,
        uint _value,
       string calldata _func,
        bytes calldata _data,
        string calldata _note
    ) public onlyOwner {
        // uint txIndex = transactions.length;
        // transactions.push(
        //     Transaction({
        //         target: _target,
        //         value: _value,
        //         func : _func,
        //         data: _data,
        //         executed: false,
        //         numConfirmations: 0
        //     })
        // );

        transactions[Txindex.current()]= Transaction({
             target: _target,
                value: _value,
                func : _func,
                data: _data,
                note:_note,
                executed: false,
                numConfirmations: 0

        });

        Txindex.increment();

        emit SubmitTransaction(msg.sender, Txindex.current(), _target, _value, _data);
    }

    function confirmTransaction(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {
        // require(transactions.length<11,"you have exceeded your transaction limit ");
        require(isConfirmed[_txIndex][msg.sender] = false,"aldready confirmed by the user");
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;
         // prepare data
        bytes memory data;
        if (bytes(transaction.func).length > 0) {
            // data = func selector + _data
            data = abi.encodePacked(bytes4(keccak256(bytes(transaction.func))),transaction.data);
        } else {
            // call fallback with data
            data = transaction.data;
        }

        // call target
        (bool success, ) = transaction.target.call{value: transaction.value}(data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }
   


    function getOwners() public view returns (address[] memory) {
        return owners;
    }


    function getTransaction(
        uint _txIndex
    )
        public
        view
        returns (
            address target,
            uint value,
            string memory _func,
            bytes memory data,
            string memory note,
            bool executed,
            uint numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.target,
            transaction.value,
            transaction.func,
            transaction.data,
            transaction.note,
            transaction.executed,
            transaction.numConfirmations
        );
    }
   

   
    
}
