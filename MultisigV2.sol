// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Counters.sol";


interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}
interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

contract MultiSigWalletV2 {
    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to
    );
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public numConfirmationsRequired;

    //type of txn = 1 ->erc20 
    //type of txn = 2 ->erc721 

    struct TokenTxn {
        address to;
        address token;
        uint256 amountOrTokenid;
        string note;
        bool executed;
        uint8 numConfirmations;
        uint8 typeoftxn ;

    }

    // mapping from tx index => owner => bool
    mapping(uint => mapping(address => bool)) public isConfirmed;

    using Counters for Counters.Counter;
  
    Counters.Counter private Tokenindex;

   
    //mapping  token txn to token index
    mapping(uint => TokenTxn) public tokenTxn;

   
    // Transaction[] public transactions;                               

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }
    
      modifier txExists(uint _txIndex) {
        require(tokenTxn[_txIndex].to==address(0), "tx does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!tokenTxn[_txIndex].executed, "tx already executed");
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
        address _to,
        address _token,
        uint256 _amountOrTokenid,
        string calldata _note,
        uint8 _typeoftxn
    ) public onlyOwner {
       require(_typeoftxn<=2,"only enter 1 or 2");
        tokenTxn[Tokenindex.current()]= TokenTxn({
                to: _to,
                token: _token,
                amountOrTokenid: _amountOrTokenid,
                note:_note,
                executed: false,
                numConfirmations: 0,
                typeoftxn:_typeoftxn


        });

        Tokenindex.increment();

        emit SubmitTransaction(msg.sender, Tokenindex.current(),_to);
    }

    function confirmTransaction(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {
        TokenTxn storage transaction = tokenTxn[_txIndex];
        transaction.numConfirmations += 1;
       
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        TokenTxn storage transaction = tokenTxn[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;
        if(transaction.typeoftxn == 1)
        {
            IERC20(transaction.token).transfer(transaction.to,transaction.amountOrTokenid);
        }
        else if(transaction.typeoftxn == 2){
             IERC721(transaction.token).safeTransferFrom(address(this),transaction.to,transaction.amountOrTokenid);
        }
       

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(
        uint _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        TokenTxn storage transaction = tokenTxn[_txIndex];

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
            address to,
            address token,
            uint amountOrtokenid,
            string memory note,
            bool executed,
            uint8 numConfirmations,
            uint8 typeoftxn
        )
    {
        TokenTxn storage transaction = tokenTxn[_txIndex];

        return (
            transaction.to,
            transaction.token,
            transaction.amountOrTokenid,
            transaction.note,
            transaction.executed,
            transaction.numConfirmations,
            transaction.typeoftxn
        );
    }
  
    
}
