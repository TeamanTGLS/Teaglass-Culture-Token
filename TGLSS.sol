// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 CLEAN ERC20 + OPTIONAL AUTO LP
 - Single file
 - No inheritance jungle
 - Verify-friendly
*/

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract TGLSS is IERC20 {

    string public constant name     = "TEAGLASS";
    string public constant symbol   = "TGLSS";
    uint8  public constant decimals = 5;

    uint256 private constant _totalSupply = 18101981000 * 10**decimals;

    address public owner;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // --- TAX / LP ---
    uint256 public taxPercent = 15; // 1.5%  (15 / 1000)
    uint256 public constant TAX_DIVISOR = 1000;

    bool public autoLPEnabled = false;

    IUniswapV2Router02 public router;
    address public pair;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address routerAddress) {
        owner = msg.sender;
        router = IUniswapV2Router02(routerAddress);

        pair = IUniswapV2Factory(router.factory())
            .createPair(address(this), router.WETH());

        _balances[owner] = _totalSupply;
        emit Transfer(address(0), owner, _totalSupply);
    }

    // --- ERC20 ---
    function totalSupply() external pure override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address o, address spender) external view override returns (uint256) {
        return _allowances[o][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        require(allowed >= amount, "Allowance low");
        _allowances[from][msg.sender] = allowed - amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(_balances[from] >= amount, "Balance low");

        uint256 tax = 0;
        if (autoLPEnabled && from != owner && to != owner) {
            tax = (amount * taxPercent) / TAX_DIVISOR;
        }

        uint256 sendAmount = amount - tax;

        _balances[from] -= amount;
        _balances[to]   += sendAmount;
        emit Transfer(from, to, sendAmount);

        if (tax > 0) {
            _balances[address(this)] += tax;
            emit Transfer(from, address(this), tax);
        }
    }

    // --- OWNER CONTROLS ---
    function enableAutoLP(bool status) external onlyOwner {
        autoLPEnabled = status;
    }

    function setTaxPercent(uint256 newTax) external onlyOwner {
        require(newTax <= 30, "Max 3%");
        taxPercent = newTax;
    }

    function rescueTokens(address token) external onlyOwner {
        IERC20(token).transfer(owner, IERC20(token).balanceOf(address(this)));
    }

    receive() external payable {}
}