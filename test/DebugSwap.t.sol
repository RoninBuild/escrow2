// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Escrow.sol";

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IUniswapV3Pool {
    function liquidity() external view returns (uint128);
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked);
}

contract DebugSwapTest is Test {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant TOWNS = 0x00000000A22C618fd6b4D7E9A335C4B96B189a38;
    address constant UNISWAP_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address constant SWAP_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;

    function setUp() public {
        // Fork Base mainnet at latest block
        vm.createSelectFork("https://mainnet.base.org");
    }

    function test_checkPool() public view {
        console2.log("=== Checking USDC/TOWNS pools ===");
        
        IUniswapV3Factory factory = IUniswapV3Factory(UNISWAP_FACTORY);
        
        // Check all fee tiers
        uint24[4] memory fees = [uint24(100), uint24(500), uint24(3000), uint24(10000)];
        string[4] memory feeNames = ["0.01%", "0.05%", "0.3%", "1%"];
        
        for (uint i = 0; i < fees.length; i++) {
            address pool = factory.getPool(USDC, TOWNS, fees[i]);
            console2.log("Fee tier", feeNames[i], "pool:", pool);
            
            if (pool != address(0)) {
                IUniswapV3Pool p = IUniswapV3Pool(pool);
                uint128 liq = p.liquidity();
                console2.log("  Liquidity:", liq);
            }
        }
    }

    function test_simulateSwap() public {
        console2.log("=== Simulating Multi-Hop swap (USDC->WETH->TOWNS) ===");
        
        // Multi-hop path: USDC(500) -> WETH(10000) -> TOWNS
        // WETH: 0x4200000000000000000000000000000000000006
        address weth = 0x4200000000000000000000000000000000000006;
        
        // Check USDC balance we can use
        uint256 usdcAmount = 100000000; // 100 USDC (6 decimals)
        
        // Get some USDC for testing
        address whale = 0x3304E22DDaa22bCdC5fCa2269b418046aE7b566A; // Known USDC holder
        vm.prank(whale);
        IERC20(USDC).transfer(address(this), usdcAmount);
        
        console2.log("USDC balance:", IERC20(USDC).balanceOf(address(this)));
        
        // Approve router
        IERC20(USDC).approve(SWAP_ROUTER, usdcAmount);
        
        // Try the swap with encoding (Use 3000/0.3% for USDC/WETH as it has better liquidity)
        bytes memory path = abi.encodePacked(USDC, uint24(3000), weth, uint24(10000), TOWNS);

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: usdcAmount,
            amountOutMinimum: 1
        });
        
        console2.log("Attempting swap...");
        
        uint256 amountOut = ISwapRouter(SWAP_ROUTER).exactInput(params);
        console2.log("Swap SUCCESS! Got TOWNS:", amountOut);
    }
}
