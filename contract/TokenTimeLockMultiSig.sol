//Deployed example on ropsten network
//https://ropsten.etherscan.io/tx/0xc70564ced5617635b3a9f9376ad3e71d84c0ccba5f0644d262eacc880c50cdf2

pragma solidity ^0.6.10;

interface IERC20 {
    function totalSupply() external view returns (uint supply);
    function balanceOf(address _owner) external view returns (uint balance);
    function transfer(address _to, uint _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint _value) external returns (bool success);
    function approve(address _spender, uint _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint remaining);
    function decimals() external view returns(uint digits);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}

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
    event TotalBalance(address sender, uint _value, uint balance);
    event OwnershipTransferred(address isMainOwner, address newOwner);
    event FundSent(address indexed _beneficiary, uint _amount);

    address public isMainOwner;
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public numConfirmationsRequired;
    uint256 public releaseTime;
    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        mapping(address => bool) isConfirmed;
        uint numConfirmations;
        bool isToken;
    }
    
    Transaction[] public transactions;
    
    
modifier mainOwner(){
    require(msg.sender == isMainOwner, "Only the main owner is allowed to call this function");
    _;
}
    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!transactions[_txIndex].isConfirmed[msg.sender], "tx already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint _numConfirmationsRequired) public {
        isMainOwner = msg.sender;
        owners.push(isMainOwner);
        isOwner[isMainOwner] =true;
        require(_owners.length > 0, "owners required");
        require(
            _numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length,
            "invalid number of required confirmations"
        );

        for (uint i = 1; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }
        releaseTime = now + ( 52 weeks);
        numConfirmationsRequired = _numConfirmationsRequired;
    }

    receive() payable external {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

 function depositEther(uint _amount) public payable {
    
     _amount =msg.value;
     address(this).balance+ msg.value;
     emit TotalBalance(msg.sender, msg.value, address(this).balance);
 } 

    function submitTransaction(address _to, uint _value, bytes memory _data)
        public
        mainOwner
    {
        uint txIndex = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            numConfirmations: 0,
            isToken: false
        }));

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }
    
    function submitERC20Transaction(IERC20 _token, address _to, uint _amount, bytes memory _data)
        public
        mainOwner
    {
        uint256 availBalance = _token.balanceOf(address(this));
        require(availBalance > 0, "insufficient token balance");
        require(_amount <= availBalance, "insufficient token balance");
        uint txIndex = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _amount,
            data: _data,
            executed: false,
            numConfirmations: 0,
            isToken: true
        }));

        emit SubmitTransaction(msg.sender, txIndex, _to, _amount, _data);
    }
    
    function getTokenBal(IERC20 _token) public view returns(uint256 balance) {
        return _token.balanceOf(address(this));
    }

    function withdrawToken(address _token, uint256 _amount, address _to, uint _txIndex) public onlyOwner txExists(_txIndex)
        notExecuted(_txIndex) returns(bool success){
        // require(block.timestamp >= releaseTime);
        IERC20 token = IERC20(_token);
        require(block.timestamp >= releaseTime, "Failed: wait for releaseTime");
        uint256 amount = token.balanceOf(address(this));
        require(_amount <= amount, "insufficient balance");
        emit ExecuteTransaction(msg.sender, _txIndex);
        require(token.transfer(_to, _amount), "Transaction failed");
        return true;
        
    }
    
    function confirmTransaction(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        transaction.isConfirmed[msg.sender] = true;
        transaction.numConfirmations += 1;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        require(block.timestamp >= releaseTime, "Failed: wait for releaseTime");
        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(transaction.isConfirmed[msg.sender], "tx not confirmed");

        transaction.isConfirmed[msg.sender] = false;
        transaction.numConfirmations -= 1;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }
    
    function addOwner(address _newOwner) public  mainOwner {
    owners.push(_newOwner);
}

  function transferOwnership(address newOwner) public mainOwner {
        _transferOwnership(newOwner);
    }
 function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(isMainOwner, newOwner);
        isMainOwner = newOwner;
    }


    function getOwners() public view returns (address[] memory) {
        return owners;
    }
    

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    function getTransaction(uint _txIndex)
        public
        view
        returns (address to, uint value, bytes memory data, bool executed, uint numConfirmations)
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
    
    function getBalance ()  public view returns (uint256) {
         return address(this).balance;
    }

    function isConfirmed(uint _txIndex, address _owner)
        public
        view
        returns (bool)
    {
        Transaction storage transaction = transactions[_txIndex];

        return transaction.isConfirmed[_owner];
    }
    
    
     function increaseTimeLock()public onlyOwner {
        releaseTime = releaseTime + (1 weeks);
    }
    
     function reduceTimeLock()public onlyOwner {
        releaseTime = releaseTime - (1 weeks);
    }
    
    function changeReleaseTime(uint256 _time) public onlyOwner {
        // enter time in block value
        releaseTime = _time;
    }
}