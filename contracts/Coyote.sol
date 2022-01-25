// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IPancakeV2Factory.sol";

contract Coyote is IERC20, IERC20Metadata, Context, Ownable { 
    struct UserBalanceVolume {
        uint256 amount;
        uint256 lastUpdate;
    }

    uint256 private _previousVolume;
    uint256 private _volume;
    uint256 private _nextResetTimesamp;
    uint256 private _previousResetTimestamp;
    mapping(address => UserBalanceVolume) public userSellBalanceVolume;

    string private _name;
    string private _symbol;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;

    mapping(address => bool) private _isExcludedFromFee;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 2500000000000000 * 10**18;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    uint256 public constant FEE_DECIMALS = 1;

    uint256 public _burnFee = 30;
    uint256 private _previousBurnFee = _burnFee;

    uint256 public _swapFee = 25;
    uint256 private _previousSwapFee = _swapFee;

    uint256 public _redistributeFee = 55;
    uint256 private _previousRedistributeFee = _redistributeFee;

    address public teamAddress;
    address public reserveAddress;
    address public publicSaleAddress;

    address public constant ZERO_ADDRESS =
        address(0);

    IPancakeRouter02 public immutable pancakeswapV2Router;
    address public pancakeswapV2Pair;

    mapping(address => bool) private _isPancakeswapV2Pair;

    bool private inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

    uint256 private numTokensSellToAddToLiquidity = 50000 * 10**18;

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );
    event SwapETHForTokens(uint256 amountIn, address[] path);
    event LiquidityFeeCollected(uint256 tokenAmount);

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(
        address _teamAddress,
        address _publicSaleAddress,
        address _reserveAddress
    ) {
        _name = "Coyote";
        _symbol = "YOTE";

        _nextResetTimesamp = block.timestamp + 1 days;

        teamAddress = _teamAddress;
        publicSaleAddress = _publicSaleAddress;
        reserveAddress = _reserveAddress;

        // 50% will be burned instantly
        _rTotal /= 2;
        _tTotal /= 2;

        uint256 onePercentT = _tTotal / 100;
        uint256 onePercentR = _rTotal / 100;

        // 2% for DEX Liquidity
        _rOwned[_msgSender()] = onePercentR * 2;
        _previousVolume += 25000000000000 * 10**18;

        // 15% to Team
        _rOwned[teamAddress] = onePercentR * 15;

        // 63% for PublicSale
        _rOwned[publicSaleAddress] = onePercentR * 63;

        // 20% Reserve
        _rOwned[reserveAddress] = onePercentR * 20;

        IPancakeRouter02 _pancakeswapV2Router = IPancakeRouter02(
            0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        );
        // Create a uniswap pair for this new token
        pancakeswapV2Pair = IPancakeV2Factory(_pancakeswapV2Router.factory())
            .createPair(address(this), _pancakeswapV2Router.WETH());
        _isPancakeswapV2Pair[pancakeswapV2Pair] = true;
        // Set the rest of the contract variables
        pancakeswapV2Router = _pancakeswapV2Router;

        // Exclude Owner, This contract and PanCakeRouter from fees
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[address(_pancakeswapV2Router)] = true;

        emit Transfer(address(0), _msgSender(), onePercentT * 2);
        emit Transfer(address(0), teamAddress, onePercentT * 15);
        emit Transfer(address(0), publicSaleAddress, onePercentT * 63);
        emit Transfer(address(0), reserveAddress, onePercentT * 20);
        emit Transfer(address(this), address(0), _tTotal); // this is a transfer to represent the burn
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _tTotal;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return tokenFromReflection(_rOwned[account]);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        uint256 rAmount = tAmount * _getRate();
        _rOwned[sender] -= rAmount;
        _rTotal -= rAmount;
        _tFeeTotal += tAmount;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        public
        view
        returns (uint256)
    {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        uint256 currentRate = _getRate();
        if (!deductTransferFee) {
            return tAmount * currentRate;
        } else {
            uint256[4] memory tValues = _getTValues(tAmount);
            return tValues[0] * currentRate;
        }
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    function addPancakeswapV2PairAddress(address account) public onlyOwner {
        _isPancakeswapV2Pair[account] = true;
    }

    function removePancakeswapV2PairAddress(address account) public onlyOwner {
        _isPancakeswapV2Pair[account] = false;
    }

    function setBurnFee(uint256 fee) external onlyOwner {
        _burnFee = fee;
    }

    function setLiquidityFeePercent(uint256 fee) external onlyOwner {
        _swapFee = fee;
    }

    function setRedistributeFee(uint256 fee) external onlyOwner {
        _redistributeFee = fee;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    //to recieve ETH from pancakeswapV2Router when swaping
    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    function _reflectFee(uint256 tFee, uint256 rFee) private {
        _rTotal -= rFee;
        _tFeeTotal += tFee;
    }

    function _getTValues(uint256 tAmount)
        private
        view
        returns (uint256[4] memory)
    {
        uint256[4] memory tValues;
        tValues[1] = calculateRedistibuteFee(tAmount);
        tValues[2] = calculateLiquidityFee(tAmount); 
        tValues[3] = calculateBurnFee(tAmount); 
        tValues[0] = tAmount - tValues[1] - tValues[2] - tValues[3]; 
        return tValues;
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 tLiquidity, uint256 rLiquidity) private {
        _rOwned[address(this)] += rLiquidity;
        emit LiquidityFeeCollected(tLiquidity);
    }

    function _burn(uint256 tBurn, uint256 rBurn) private {
        _tTotal -= tBurn;
        _rTotal -= rBurn;

        emit Transfer(msg.sender, ZERO_ADDRESS, tBurn);
    }

    function calculateRedistibuteFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return (_amount * _redistributeFee) / (10**FEE_DECIMALS * 100);
    }

    function calculateLiquidityFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return (_amount * _swapFee) / (10**FEE_DECIMALS * 100);
    }

    function calculateBurnFee(uint256 _amount) private view returns (uint256) {
        return (_amount * _burnFee) / (10**FEE_DECIMALS * 100);
    }

    function removeAllFee() private {
        if (_redistributeFee == 0 && _swapFee == 0 && _burnFee == 0) return;

        _previousRedistributeFee = _redistributeFee;
        _previousSwapFee = _swapFee;
        _previousBurnFee = _burnFee;

        _redistributeFee = 0;
        _swapFee = 0;
        _burnFee = 0;
    }

    function restoreAllFee() private {
        _redistributeFee = _previousRedistributeFee;
        _swapFee = _previousSwapFee;
        _burnFee = _previousBurnFee;
    }

    function isPancakeswapV2PairAddress(address account)
        public
        view
        returns (bool)
    {
        return _isPancakeswapV2Pair[account];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));

        bool overMinTokenBalance = contractTokenBalance >=
            numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            !_isPancakeswapV2Pair[from] &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }

        // indicates if fee should be deducted from transfer
        bool takeFee = true;

        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        // transfer amount, it will take tax, burn, liquidity, marketing fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half;

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance - initialBalance;

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeswapV2Router.WETH();

        _approve(address(this), address(pancakeswapV2Router), tokenAmount);

        // make the swap
        pancakeswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(pancakeswapV2Router), tokenAmount);

        // add the liquidity
        pancakeswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee
    ) private {
        if (!takeFee) {
            removeAllFee();
        }

        uint256 currentRate = _getRate();
        if (takeFee) {
            // sell
            if (_isPancakeswapV2Pair[recipient]) {
                if (_nextResetTimesamp >= block.timestamp) {
                    _volume += tAmount;

                    userSellBalanceVolume[sender]
                        .amount = userSellBalanceVolume[sender].lastUpdate <=
                        _nextResetTimesamp - 1 days
                        ? tAmount
                        : userSellBalanceVolume[sender].amount + tAmount;
                } else {
                    do {
                        _previousResetTimestamp = _nextResetTimesamp;
                        _nextResetTimesamp += 1 days;
                    } while (_nextResetTimesamp < block.timestamp);

                    _previousVolume = _volume;
                    _volume = tAmount;
                    userSellBalanceVolume[sender].amount = tAmount;

                }
                userSellBalanceVolume[sender].lastUpdate = block.timestamp;
                if (
                    userSellBalanceVolume[sender].amount >
                    (_previousVolume * 5) / 100
                ) {
                    _redistributeFee = 245;
                }
            }

            // tValues[0] -> tTransferAmount -> Token transfer amount less fees
            // tValues[1] -> tRedistributeFee -> Redistribute amount
            // tValues[2] -> tLiquidity -> Liquidity fee amount
            // tValues[3] -> tburnFee -> Burn fee amount
            uint256[4] memory tValues = _getTValues(tAmount);

            // Collects liquidity tokens
            _takeLiquidity(tValues[2], tValues[2] * currentRate);

            // Burns tokens
            _burn(tValues[3], tValues[3] * currentRate);

            // Redistributes tokens
            _reflectFee(tValues[1], tValues[1] * currentRate);
            _redistributeFee = 55;

            _rOwned[sender] -= (tAmount * currentRate);
            _rOwned[recipient] += (tValues[0] * currentRate);

            emit Transfer(sender, recipient, tValues[0]);
        } else {
            _rOwned[sender] -= (tAmount * currentRate);
            _rOwned[recipient] += (tAmount * currentRate);
            emit Transfer(sender, recipient, tAmount);
        }

        if (!takeFee) {
            restoreAllFee();
        }
    }


    /// @notice Getter for previous volume amount
    /// @return amount uint256 volume amount
    function getPreviousVolume() public view returns (uint256 amount) {
        return _previousVolume;
    }


    /// @notice Getter for next reset timestamp
    /// @return timestamp uint256 reset timestamp
    function getNextResetTimestamp() public view returns (uint256 timestamp) {
        return _nextResetTimesamp;
    }
}

