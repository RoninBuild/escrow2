// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFactory {
    function getPool(address, address, uint24) external view returns (address);
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

contract TestSwapScript is Script {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant TOWNS = 0x00000000A22C618fd6b4D7E9A335C4B96B189a38;
    address constant ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address constant FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;

    function run() external {
        address tester = address(0x1337);
        vm.deal(tester, 1 ether);
        
        console2.log("Tester:", tester);
        vm.startPrank(tester);

        // 1. Wrap ETH -> WETH
        console2.log("Wrapping ETH...");
        (bool success,) = WETH.call{value: 0.1 ether}("");
        require(success, "Wrap failed");
        console2.log("WETH Balance:", IERC20(WETH).balanceOf(tester));

        // 2. Approve Router
        uint256 amountIn = 0.01 ether;
        IERC20(WETH).approve(ROUTER, amountIn);

        // 3. Swap WETH -> TOWNS (1% pool)
        console2.log("Attempting WETH -> TOWNS (1%)...");
        
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: WETH,
            tokenOut: TOWNS,
            fee: 10000,
            recipient: tester,
            deadline: block.timestamp + 1000,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        uint256 townsOut = ISwapRouter(ROUTER).exactInputSingle(params);
        console2.log("SUCCESS! Got TOWNS:", townsOut);

        vm.stopPrank();
    }
}
