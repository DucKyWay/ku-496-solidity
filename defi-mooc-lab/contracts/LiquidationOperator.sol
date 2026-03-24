//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "hardhat/console.sol";

interface ILendingPool {
    function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken) external;
    function getUserAccountData(address user) external view returns (uint256 totalCollateralETH, uint256 totalDebtETH, uint256 availableBorrowsETH, uint256 currentLiquidationThreshold, uint256 ltv, uint256 healthFactor);
}

interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);
    function approve(address spender, uint256 value) external;
    function transfer(address to, uint256 value) external returns (bool);
}

interface IWETH is IERC20 {
    function withdraw(uint256) external;
}

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Pair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract LiquidationOperator is IUniswapV2Callee {
    uint8 public constant health_factor_decimals = 18;

    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    IUniswapV2Factory constant uniswapV2Factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    IUniswapV2Pair immutable uniswapV2Pair_USDC_WETH; 

    ILendingPool constant lendingPool = ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    address constant liquidationTarget = 0x63f6037d3e9d51ad865056BF7792029803b6eEfD;
    uint256 debt_USDC; 

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256 amountIn) {
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    constructor() {
        uniswapV2Pair_USDC_WETH = IUniswapV2Pair(uniswapV2Factory.getPair(address(USDC), address(WETH)));
        debt_USDC = 5000 * 1e6; 
    }

    receive() external payable {}

    function operate() external {
        (,,,,,uint256 healthFactor) = lendingPool.getUserAccountData(liquidationTarget);
        require(healthFactor < (10 ** health_factor_decimals), "Cannot liquidate; health factor must be below 1");

        uniswapV2Pair_USDC_WETH.swap(debt_USDC, 0, address(this), "$");

        uint256 balanceWETH = WETH.balanceOf(address(this));
        if (balanceWETH > 0) {
            WETH.withdraw(balanceWETH);
            payable(msg.sender).transfer(address(this).balance);
        }
    }

    function uniswapV2Call(address, uint256 amount0, uint256, bytes calldata) external override {
        assert(msg.sender == address(uniswapV2Pair_USDC_WETH));


        (uint256 reserve0, uint256 reserve1, ) = uniswapV2Pair_USDC_WETH.getReserves();

 
        uint256 amountBorrowed = amount0; 
        USDC.approve(address(lendingPool), amountBorrowed);
        
        console.log("--- START LIQUIDATION ---");
        lendingPool.liquidationCall(address(WETH), address(USDC), liquidationTarget, amountBorrowed, false);
        
        uint256 collateral_WETH = WETH.balanceOf(address(this));
        console.log("Collateral WETH received:", collateral_WETH);


        uint256 repay_WETH = getAmountIn(amountBorrowed, reserve1, reserve0);
        console.log("WETH needed to repay Uniswap:", repay_WETH);

        require(collateral_WETH > repay_WETH, "Not profitable");

        WETH.transfer(address(uniswapV2Pair_USDC_WETH), repay_WETH);
        
        console.log("Profit WETH:", collateral_WETH - repay_WETH);
        console.log("--- SUCCESS ---");
    }
}