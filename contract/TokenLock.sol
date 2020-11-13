pragma solidity ^0.6.1;

interface ERC20 {
    function totalSupply() external view returns (uint256 supply);

    function balanceOf(address _owner) external view returns (uint256 balance);

    function transfer(address _to, uint256 _value)
        external
        returns (bool success);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    function approve(address _spender, uint256 _value)
        external
        returns (bool success);

    function allowance(address _owner, address _spender)
        external
        view
        returns (uint256 remaining);

    function decimals() external view returns (uint256 digits);

    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );
}

contract TokenTimelock {
    uint256 public releaseTime;
    event FundSent(address indexed _beneficiary, uint256 _amount);
    event FundReceived(address indexed _from, uint256 _amount);
    address owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    receive() external payable {
        emit FundReceived(msg.sender, msg.value);
    }

    constructor() public {
        // require(_releaseTime > block.timestamp);
        releaseTime = now + (52 weeks);
        owner = msg.sender;
    }

    function withdrawToken(
        address _token,
        uint256 _amount,
        address _to
    ) public onlyOwner returns (bool success) {
        // require(block.timestamp >= releaseTime);
        ERC20 token = ERC20(_token);
        require(now >= releaseTime, "Failed: wait for releaseTime");
        uint256 amount = token.balanceOf(address(this));
        require(_amount <= amount, "insufficient balance");
        emit FundSent(_to, _amount);
        require(token.transfer(_to, _amount), "Transaction failed");
        return true;
    }

    function withdrawEth(uint256 _amount, address payable _to)
        public
        onlyOwner
    {
        // require(block.timestamp >= releaseTime);
        require(now >= releaseTime, "Failed: wait till releaseTime");
        require(_amount <= address(this).balance);

        (bool success, ) = address(_to).call{value: _amount}(
            abi.encodeWithSignature("nonExistingFunction()")
        );
        require(success, "tx failed");

        emit FundSent(msg.sender, _amount);
    }

    function getEtherBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getTokenBalance(ERC20 _token) public view returns (uint256) {
        return _token.balanceOf(address(this));
    }

    function increaseTimeLock() public onlyOwner {
        releaseTime = releaseTime + (2 weeks);
    }
}
