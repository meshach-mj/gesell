// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Gesell (GSLL)
 * @notice A demurrage currency that decays over time to encourage circulation
 * @dev Implements Silvio Gesell's 1916 theory of "free money"
 * 
 * Key mechanics:
 * - Balances decay at 0.01% every 300,000 seconds (~3.47 days)
 * - Backed by USDC at a variable exchange rate
 * - Transaction fee of 0.01 USDC/GSLL on mint, redeem, and transfer
 */
contract Gesell is IERC20, IERC20Metadata, Ownable, ReentrancyGuard {
    
    // ============ Constants ============
    
    string private constant _name = "Gesell";
    string private constant _symbol = "GSLL";
    uint8 private constant _decimals = 6;
    
    uint256 public constant DECAY_PERIOD = 300_000; // seconds
    uint256 public constant DECAY_RATE_NUMERATOR = 9999; // 0.01% decay = 99.99% remaining
    uint256 public constant DECAY_RATE_DENOMINATOR = 10000;
    uint256 public constant TRANSACTION_FEE = 10_000; // 0.01 USDC/GSLL (6 decimals)
    
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    // Base mainnet USDC
    IERC20 public immutable usdc;
    
    // ============ State Variables ============
    
    // Mint price: how many USDC for 1 GSLL (6 decimals)
    // Launch: 37.07 USDC = 37_070_000 (6 decimals)
    uint256 public mintPrice;
    
    // Fee recipient
    address public feeRecipient;
    
    // Deployment timestamp for decay calculation
    uint256 public immutable deploymentTime;
    
    // Internal accounting uses "shares" which don't decay
    // Actual balance = shares * decay_factor
    mapping(address => uint256) private _shares;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // Total shares (not decayed)
    uint256 private _totalShares;
    
    // Track last interaction time for each account
    mapping(address => uint256) private _lastUpdateTime;
    
    // ============ Events ============
    
    event Mint(address indexed to, uint256 usdcAmount, uint256 gsllAmount);
    event Redeem(address indexed from, uint256 gsllAmount, uint256 usdcAmount);
    event MintPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    
    // ============ Constructor ============
    
    /**
     * @param _usdc Address of USDC contract on Base
     * @param _mintPrice Initial mint price (USDC per GSLL, 6 decimals)
     * @param _feeRecipient Address to receive transaction fees
     */
    constructor(
        address _usdc,
        uint256 _mintPrice,
        address _feeRecipient
    ) Ownable(msg.sender) {
        require(_usdc != address(0), "Invalid USDC address");
        require(_mintPrice > 0, "Invalid mint price");
        require(_feeRecipient != address(0), "Invalid fee recipient");
        
        usdc = IERC20(_usdc);
        mintPrice = _mintPrice;
        feeRecipient = _feeRecipient;
        deploymentTime = block.timestamp;
    }
    
    // ============ ERC20 Metadata ============
    
    function name() external pure override returns (string memory) {
        return _name;
    }
    
    function symbol() external pure override returns (string memory) {
        return _symbol;
    }
    
    function decimals() external pure override returns (uint8) {
        return _decimals;
    }
    
    // ============ Decay Calculation ============
    
    /**
     * @notice Calculate decay factor for a given number of periods
     * @dev Uses iterative multiplication to avoid overflow
     * @param periods Number of 300,000-second periods
     * @return Decay factor (multiply by balance, divide by 10^(periods counted))
     */
    function _calculateDecayFactor(uint256 periods) internal pure returns (uint256) {
        if (periods == 0) return DECAY_RATE_DENOMINATOR;
        if (periods > 10000) periods = 10000; // Cap to prevent gas issues
        
        uint256 factor = DECAY_RATE_DENOMINATOR;
        uint256 base = DECAY_RATE_NUMERATOR;
        
        // Binary exponentiation for efficiency
        while (periods > 0) {
            if (periods % 2 == 1) {
                factor = (factor * base) / DECAY_RATE_DENOMINATOR;
            }
            base = (base * base) / DECAY_RATE_DENOMINATOR;
            periods /= 2;
        }
        
        return factor;
    }
    
    /**
     * @notice Get the current decay factor since deployment
     * @return Current decay factor (out of DECAY_RATE_DENOMINATOR)
     */
    function currentDecayFactor() public view returns (uint256) {
        uint256 elapsed = block.timestamp - deploymentTime;
        uint256 periods = elapsed / DECAY_PERIOD;
        return _calculateDecayFactor(periods);
    }
    
    /**
     * @notice Convert shares to actual balance (apply decay)
     * @param shares Internal share amount
     * @return Actual token balance after decay
     */
    function _sharesToBalance(uint256 shares) internal view returns (uint256) {
        return (shares * currentDecayFactor()) / DECAY_RATE_DENOMINATOR;
    }
    
    /**
     * @notice Convert balance to shares (reverse decay)
     * @param balance Desired token balance
     * @return Required shares
     */
    function _balanceToShares(uint256 balance) internal view returns (uint256) {
        uint256 factor = currentDecayFactor();
        if (factor == 0) return 0;
        return (balance * DECAY_RATE_DENOMINATOR) / factor;
    }
    
    // ============ ERC20 Core Functions ============
    
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
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Approve from zero address");
        require(spender != address(0), "Approve to zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "Insufficient allowance");
            _approve(from, msg.sender, currentAllowance - amount);
        }
        _transfer(from, to, amount);
        return true;
    }
    
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        
        uint256 fromBalance = balanceOf(from);
        require(fromBalance >= amount + TRANSACTION_FEE, "Insufficient balance (including fee)");
        
        // Calculate shares for the amount being transferred
        uint256 amountShares = _balanceToShares(amount);
        uint256 feeShares = _balanceToShares(TRANSACTION_FEE);
        
        require(_shares[from] >= amountShares + feeShares, "Insufficient shares");
        
        _shares[from] -= (amountShares + feeShares);
        _shares[to] += amountShares;
        _shares[feeRecipient] += feeShares;
        
        emit Transfer(from, to, amount);
        emit Transfer(from, feeRecipient, TRANSACTION_FEE);
    }
    
    // ============ Mint and Redeem ============
    
    /**
     * @notice Mint GSLL by depositing USDC
     * @param usdcAmount Amount of USDC to deposit
     */
    function mint(uint256 usdcAmount) external nonReentrant {
        require(usdcAmount > TRANSACTION_FEE, "Amount must cover fee");
        
        // Transfer USDC from user
        require(usdc.transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");
        
        // Deduct fee
        uint256 usdcAfterFee = usdcAmount - TRANSACTION_FEE;
        
        // Send fee to recipient
        require(usdc.transfer(feeRecipient, TRANSACTION_FEE), "Fee transfer failed");
        
        // Calculate GSLL to mint
        uint256 gsllAmount = (usdcAfterFee * (10 ** _decimals)) / mintPrice;
        require(gsllAmount > 0, "GSLL amount too small");
        
        // Convert to shares and mint
        uint256 shares = _balanceToShares(gsllAmount);
        _shares[msg.sender] += shares;
        _totalShares += shares;
        
        emit Mint(msg.sender, usdcAmount, gsllAmount);
        emit Transfer(address(0), msg.sender, gsllAmount);
    }
    
    /**
     * @notice Redeem GSLL for USDC
     * @param gsllAmount Amount of GSLL to redeem
     */
    function redeem(uint256 gsllAmount) external nonReentrant {
        uint256 balance = balanceOf(msg.sender);
        require(balance >= gsllAmount, "Insufficient balance");
        
        // Calculate USDC to return
        uint256 usdcAmount = (gsllAmount * mintPrice) / (10 ** _decimals);
        require(usdcAmount > TRANSACTION_FEE, "USDC amount must cover fee");
        
        uint256 usdcAfterFee = usdcAmount - TRANSACTION_FEE;
        
        // Calculate shares to burn
        uint256 shares = _balanceToShares(gsllAmount);
        require(_shares[msg.sender] >= shares, "Insufficient shares");
        
        _shares[msg.sender] -= shares;
        _totalShares -= shares;
        
        // Calculate USDC that should be burned (from decay)
        // This is the difference between what was deposited and what's being returned
        uint256 contractBalance = usdc.balanceOf(address(this));
        uint256 theoreticalBalance = (_totalShares * mintPrice * currentDecayFactor()) / 
                                      (DECAY_RATE_DENOMINATOR * (10 ** _decimals));
        
        if (contractBalance > theoreticalBalance + usdcAfterFee + TRANSACTION_FEE) {
            uint256 excessUsdc = contractBalance - theoreticalBalance - usdcAfterFee - TRANSACTION_FEE;
            // Send excess to burn address
            if (excessUsdc > 0) {
                usdc.transfer(BURN_ADDRESS, excessUsdc);
            }
        }
        
        // Send fee to recipient
        require(usdc.transfer(feeRecipient, TRANSACTION_FEE), "Fee transfer failed");
        
        // Send USDC to user
        require(usdc.transfer(msg.sender, usdcAfterFee), "USDC transfer failed");
        
        emit Redeem(msg.sender, gsllAmount, usdcAfterFee);
        emit Transfer(msg.sender, address(0), gsllAmount);
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Update the mint price (USDC per GSLL)
     * @param newPrice New mint price (6 decimals)
     */
    function updateMintPrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "Invalid price");
        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;
        emit MintPriceUpdated(oldPrice, newPrice);
    }
    
    /**
     * @notice Update the fee recipient address
     * @param newRecipient New fee recipient
     */
    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Invalid address");
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get the number of decay periods elapsed since deployment
     */
    function periodsElapsed() external view returns (uint256) {
        return (block.timestamp - deploymentTime) / DECAY_PERIOD;
    }
    
    /**
     * @notice Calculate how much GSLL you'd receive for a given USDC amount
     * @param usdcAmount Amount of USDC
     * @return GSLL amount (after fee)
     */
    function previewMint(uint256 usdcAmount) external view returns (uint256) {
        if (usdcAmount <= TRANSACTION_FEE) return 0;
        uint256 usdcAfterFee = usdcAmount - TRANSACTION_FEE;
        return (usdcAfterFee * (10 ** _decimals)) / mintPrice;
    }
    
    /**
     * @notice Calculate how much USDC you'd receive for a given GSLL amount
     * @param gsllAmount Amount of GSLL
     * @return USDC amount (after fee)
     */
    function previewRedeem(uint256 gsllAmount) external view returns (uint256) {
        uint256 usdcAmount = (gsllAmount * mintPrice) / (10 ** _decimals);
        if (usdcAmount <= TRANSACTION_FEE) return 0;
        return usdcAmount - TRANSACTION_FEE;
    }
    
    /**
     * @notice Get internal shares for an account (for debugging)
     * @param account Address to check
     * @return Share balance
     */
    function sharesOf(address account) external view returns (uint256) {
        return _shares[account];
    }
}
