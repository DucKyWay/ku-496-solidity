// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TokenA.sol";
import "./TokenB.sol";

contract MiniDEX {
    TokenA public tokenA;
    TokenB public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLiquidity;

    mapping(address => uint256) public liquidityBalance;

    uint256 public constant FEE_NUMERATOR = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidityMinted);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidityBurned);
    event Swap(address indexed user, uint256 amountAIn, uint256 amountBIn, uint256 amountAOut, uint256 amountBOut);

    constructor(address _tokenA, address _tokenB) {
        tokenA = TokenA(_tokenA);
        tokenB = TokenB(_tokenB);
    }

    // ฟังก์ชัน sqrt สำหรับคำนวณ initial liquidity
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        require(amountA > 0 && amountB > 0, "Amounts must be > 0");

        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        uint256 liquidityMinted;

        if (totalLiquidity == 0) {
            // คนแรก: LP = sqrt(amountA * amountB)
            liquidityMinted = _sqrt(amountA * amountB);
        } else {
            // คนถัดไป: ต้องใส่ตามสัดส่วน
            require(amountA * reserveB == amountB * reserveA, "Wrong pool ratio");
            liquidityMinted = amountA * totalLiquidity / reserveA;
        }

        liquidityBalance[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;
        reserveA += amountA;
        reserveB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidityMinted);
    }

    function removeLiquidity(uint256 liquidityAmount) external {
        require(liquidityAmount > 0, "Amount must be > 0");
        require(liquidityBalance[msg.sender] >= liquidityAmount, "Insufficient liquidity");

        // คำนวณสัดส่วนที่จะได้คืน
        uint256 amountA = liquidityAmount * reserveA / totalLiquidity;
        uint256 amountB = liquidityAmount * reserveB / totalLiquidity;

        require(amountA > 0 && amountB > 0, "Insufficient reserves");

        liquidityBalance[msg.sender] -= liquidityAmount;
        totalLiquidity -= liquidityAmount;
        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidityAmount);
    }

    function swapAforB(uint256 amountAIn) external {
        require(amountAIn > 0, "Amount must be > 0");

        // หัก fee 0.3%: คูณด้วย 997/1000
        uint256 amountAInWithFee = amountAIn * FEE_NUMERATOR / FEE_DENOMINATOR;

        // Constant product formula: (reserveA + amountAInWithFee) * (reserveB - amountBOut) = k
        uint256 amountBOut = (reserveB * amountAInWithFee) / (reserveA + amountAInWithFee);

        require(amountBOut > 0, "Insufficient output");
        require(amountBOut < reserveB, "Insufficient reserve B");

        // รับ TokenA เต็มจำนวน (fee คงอยู่ใน pool)
        tokenA.transferFrom(msg.sender, address(this), amountAIn);
        tokenB.transfer(msg.sender, amountBOut);

        // อัปเดต reserve: reserveA รับเต็ม amountAIn (fee ติดอยู่ใน pool)
        reserveA += amountAIn;
        reserveB -= amountBOut;

        emit Swap(msg.sender, amountAIn, 0, 0, amountBOut);
    }

    function swapBforA(uint256 amountBIn) external {
        require(amountBIn > 0, "Amount must be > 0");

        uint256 amountBInWithFee = amountBIn * FEE_NUMERATOR / FEE_DENOMINATOR;

        uint256 amountAOut = (reserveA * amountBInWithFee) / (reserveB + amountBInWithFee);

        require(amountAOut > 0, "Insufficient output");
        require(amountAOut < reserveA, "Insufficient reserve A");

        tokenB.transferFrom(msg.sender, address(this), amountBIn);
        tokenA.transfer(msg.sender, amountAOut);

        reserveB += amountBIn;
        reserveA -= amountAOut;

        emit Swap(msg.sender, 0, amountBIn, amountAOut, 0);
    }

    function getPriceOfAinB() external view returns (uint256) {
        require(reserveA > 0, "No liquidity");
        return reserveB * 1e18 / reserveA;
    }
}