// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    // 事件，當代幣轉移時觸發
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    // 事件，當授權額度發生變化時觸發
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // 查詢某個地址的餘額
    function balanceOf(address account) external view returns (uint256);

    // 查詢某個地址允許另一個地址可以花費的代幣數量
    function allowance(address owner, address spender) external view returns (uint256);

    // 將指定數量的代幣從呼叫者帳戶轉移到目標地址
    function transfer(address recipient, uint256 amount) external returns (bool);

    // 允許另一個地址花費指定數量的代幣
    function approve(address spender, uint256 amount) external returns (bool);

    // 從一個地址轉移代幣到另一個地址，前提是有足夠的授權額度
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    // 代幣的總供應量
    function totalSupply() external view returns (uint256);

    // 代幣的名稱
    function name() external view returns (string memory);

    // 代幣的符號，例如 ETH, USD, etc.
    function symbol() external view returns (string memory);

    // 代幣小數位數，例如 18 表示可以支持到小數點後 18 位
    function decimals() external view returns (uint8);
}

contract ERC20Token is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18; // 預設小數位數為 18
        _totalSupply = 0; // 初始供應量為 0，需進行 mint 函數增加總供應量
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        require(_allowances[sender][msg.sender] >= amount, "ERC20: transfer amount exceeds allowance");
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        require(_balances[account] >= amount, "ERC20: burn amount exceeds balance");

        _balances[account] -= amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

contract FAUCET {
    uint public amountAllowed = 100;
    address public tokenContract;
    mapping (address => bool) public requestAddress;

    event sendToken(address indexed receiver, uint indexed amount);

    constructor(address _tokenContract){
        tokenContract = _tokenContract;
    }

    function requestTokens() external {
        require(!requestAddress[msg.sender]); //每個地址只能領一次
        IERC20 token = IERC20(tokenContract);
        require(token.balanceOf(address(this)) >= amountAllowed, "Faucet Empty!");

        token.transfer(msg.sender, amountAllowed);
        requestAddress[msg.sender] = true; //紀錄領取地址

        emit sendToken(msg.sender, amountAllowed); //釋放token event
    }
}

contract AIRDROP { //純計算加總
    function getSum(uint256[] calldata _arr) public pure returns(uint sum){
        for (uint i = 0; i < _arr.length; i++ ){
            sum += _arr[i];
        }
    }

    function multiTransferToken(
        address _token,
        address[] calldata _addresses,
        uint256[] calldata _amounts
    ) external {
        require(_addresses.length == _amounts.length, "Lengths of Addresses and Amounts NOT EQUAL");
        IERC20 token = IERC20(_token);
        uint _amountSum = getSum(_amounts);
        require(token.allowance(msg.sender, address(this)) >= _amountSum, "Need Approve ERC20 token");
        
        for (uint i = 0; i < _addresses.length; i++) {
            // 若接收地址為呼叫者，則跳出錯誤
            require(_addresses[i] != msg.sender, "Cannot transfer tokens to self");
            token.transferFrom(msg.sender, _addresses[i], _amounts[i]);
        }
    }


    function multiTransferETH(
        address payable[] calldata _addresses,
        uint256[] calldata _amounts
    ) public payable {
        require(_addresses.length == _amounts.length, "Lengths of Addresses and Amounts NOT EQUAL");
        uint _amountSum = getSum(_amounts);
        require(msg.value == _amountSum, "Transfer amount error");

        for (uint8 i = 0; i < _addresses.length; i++) {
            _addresses[i].transfer(_amounts[i]);
    }
}
}
