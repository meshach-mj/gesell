// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Gesell is IERC20, IERC20Metadata, Ownable, ReentrancyGuard {
    
    string private constant _name = "Gesell";
    string private constant _symbol = "GSLL";
    uint8 private constant _decimals = 6;
    
    uint256 public constant DECAY_PERIOD = 300_000;
    uint256 public constant DECAY_RATE_NUMERATOR = 9999;
    uint256 public constant DECAY_RATE_DENOMINATOR = 10000;
    uint256 public constant TRANSACTION_FEE = 10_000;
    
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    IERC20 public immutable usdc;
    uint256 public mintPrice;
    address public feeRecipient;
    uint256 public immutable deploymentTime;
    
    mapping(address => uint256) private _shares;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalShares;

    event Mint(address indexed to, uint256 usdcAmount, uint256 gsllAmount);
    event Redeem(address indexed from, uint256 gsllAmount, uint256 usdcAmount);
    event MintPriceUpdated(uint256 oldPrice, uint256 newPrice);

    constructor(address _usdc, uint256 _mintPrice, address _feeRecipient) Ownable(msg.sender) {
        require(_usdc != address(0), "Invalid USDC");
        require(_mintPrice > 0, "Invalid price");
        require(_feeRecipient != address(0), "Invalid recipient");
        
        usdc = IERC20(_usdc);
        mintPrice = _mintPrice;
        feeRecipient = _feeRecipient;
        deploymentTime = block.timestamp;
    }

    function name() external pure override returns (string memory) { return _name; }
    function symbol() external pure override returns (string memory) { return _symbol; }
    function decimals() external pure override returns (uint8) { return _decimals; }

    function _calculateDecayFactor(uint256 periods) internal pure returns (uint256) {
        if (periods == 0) return DECAY_RATE_DENOMINATOR;
        if (periods > 10000) periods = 10000;
        
        uint256 factor = DECAY_RATE_DENOMINATOR;
        uint256 base = DECAY_RATE_NUMERATOR;
        
        while (periods > 0) {
            if (periods % 2 == 1) {
                factor = (factor * base) / DECAY_RATE_DENOMINATOR;
            }
            base = (base * base) / DECAY_RATE_DENOMINATOR;
            periods /= 2;
        }
        return factor;
    }

    function currentDecayFactor() public view returns (uint256) {
        uint256 elapsed = block.timestamp - deploymentTime;
        uint256 periods = elapsed / DECAY_PERIOD;
        return _calculateDecayFactor(periods);
    }

    function _sharesToBalance(uint256 shares) internal view returns (uint256) {
        return (shares * currentDecayFactor()) / DECAY_RATE_DENOMINATOR;
    }

    function _balanceToShares(uint256 balance) internal view returns (uint256) {
        uint256 factor = currentDecayFactor();
        if (factor == 0) return 0;
        return (balance * DECAY_RATE_DENOMINATOR) / factor;
    }

    function totalSupply() external view override returns (uint256) {
        return _sharesToBalance(_totalShares);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _sharesToBalance(_shares[account]);
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
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
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "Insufficient allowance");
            _allowances[from][msg.sender] = currentAllowance - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0) && to != address(0), "Zero address");
        
        uint256 fromBalance = balanceOf(from);
        require(fromBalance >= amount + TRANSACTION_FEE, "Insufficient balance");
        
        uint256 amountShares = _balanceToShares(amount);
        uint256 feeShares = _balanceToShares(TRANSACTION_FEE);
        
        _shares[from] -= (amountShares + feeShares);
        _shares[to] += amountShares;
        _shares[feeRecipient] += feeShares;
        
        emit Transfer(from, to, amount);
    }

    function mint(uint256 usdcAmount) external nonReentrant {
        require(usdcAmount > TRANSACTION_FEE, "Amount must cover fee");
        
        require(usdc.transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");
        
        uint256 usdcAfterFee = usdcAmount - TRANSACTION_FEE;
        require(usdc.transfer(feeRecipient, TRANSACTION_FEE), "Fee transfer failed");
        
        uint256 gsllAmount = (usdcAfterFee * (10 ** _decimals)) / mintPrice;
        require(gsllAmount > 0, "Amount too small");
        
        uint256 shares = _balanceToShares(gsllAmount);
        _shares[msg.sender] += shares;
        _totalShares += shares;
        
        emit Mint(msg.sender, usdcAmount, gsllAmount);
        emit Transfer(address(0), msg.sender, gsllAmount);
    }

    function redeem(uint256 gsllAmount) external nonReentrant {
        uint256 balance = balanceOf(msg.sender);
        require(balance >= gsllAmount, "Insufficient balance");
        
        uint256 usdcAmount = (gsllAmount * mintPrice) / (10 ** _decimals);
        require(usdcAmount > TRANSACTION_FEE, "Amount must cover fee");
        
        uint256 usdcAfterFee = usdcAmount - TRANSACTION_FEE;
        
        uint256 shares = _balanceToShares(gsllAmount);
        _shares[msg.sender] -= shares;
        _totalShares -= shares;
        
        require(usdc.transfer(feeRecipient, TRANSACTION_FEE), "Fee transfer failed");
        require(usdc.transfer(msg.sender, usdcAfterFee), "USDC transfer failed");
        
        emit Redeem(msg.sender, gsllAmount, usdcAfterFee);
        emit Transfer(msg.sender, address(0), gsllAmount);
    }

    function updateMintPrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "Invalid price");
        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;
        emit MintPriceUpdated(oldPrice, newPrice);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Invalid address");
        feeRecipient = newRecipient;
    }

    function previewMint(uint256 usdcAmount) external view returns (uint256) {
        if (usdcAmount <= TRANSACTION_FEE) return 0;
        return ((usdcAmount - TRANSACTION_FEE) * (10 ** _decimals)) / mintPrice;
    }

    function previewRedeem(uint256 gsllAmount) external view returns (uint256) {
        uint256 usdcAmount = (gsllAmount * mintPrice) / (10 ** _decimals);
        if (usdcAmount <= TRANSACTION_FEE) return 0;
        return usdcAmount - TRANSACTION_FEE;
    }
}
