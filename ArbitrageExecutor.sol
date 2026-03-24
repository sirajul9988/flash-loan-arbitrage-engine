// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV2Pair {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface IUniswapV2Router {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
}

contract ArbitrageExecutor is Ownable {
    
    constructor() Ownable(msg.sender) {}

    // 1. Initiator: Request Flash Loan from a Uniswap V2 Pair
    function startArbitrage(
        address pairAddress, 
        uint256 amount0, 
        uint256 amount1, 
        address secondaryRouter
    ) external onlyOwner {
        // Passing data triggers the 'uniswapV2Call' callback
        bytes memory data = abi.encode(secondaryRouter, msg.sender);
        IUniswapV2Pair(pairAddress).swap(amount0, amount1, address(this), data);
    }

    // 2. Callback: This is called by the Pair contract after sending us the tokens
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        address[] memory path = new address[](2);
        uint256 amountReceived = amount0 > 0 ? amount0 : amount1;
        
        (address routerAddress, address feeRecipient) = abi.decode(data, (address, address));
        
        // Logical check: ensure only the pair calls this
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        path[0] = amount0 > 0 ? token0 : token1; 
        path[1] = amount0 > 0 ? token1 : token0;

        IERC20(path[0]).approve(routerAddress, amountReceived);

        // 3. Execution: Trade on the second DEX
        uint[] memory amounts = IUniswapV2Router(routerAddress).swapExactTokensForTokens(
            amountReceived,
            0, // In production, calculate a minimum profitable amount
            path,
            address(this),
            block.timestamp + 120
        );

        // 4. Repayment: Calculate loan + 0.3% fee and pay back the pair
        uint256 amountRequired = (amountReceived * 1000) / 997 + 1;
        require(amounts[1] > amountRequired, "Arbitrage not profitable");

        IERC20(path[1]).transfer(msg.sender, amountRequired);
        
        // 5. Profit: Transfer remaining tokens to the owner
        uint256 profit = IERC20(path[1]).balanceOf(address(this));
        IERC20(path[1]).transfer(feeRecipient, profit);
    }
}
