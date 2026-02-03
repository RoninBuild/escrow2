// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/EscrowFactory.sol";

contract DeployScript is Script {
    // USDC on Base mainnet
    address constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    
    // USDC on Base Sepolia testnet
    address constant USDC_BASE_SEPOLIA = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    /// @notice Default entrypoint: deploy to Base mainnet.
    /// @dev Uses Foundry keystore when you run with `--account <name>`.
    ///      Also works with `--private-key <pk>` if you prefer.
    function run() external {
        runMainnet();
    }

    /// @notice Deploy EscrowFactory to Base mainnet.
    /// @dev Optional override: set env USDC_ADDRESS if you want a different token.
    function runMainnet() public {
        address usdc = vm.envOr("USDC_ADDRESS", USDC_BASE);

        vm.startBroadcast();

        EscrowFactory factory = new EscrowFactory(usdc);

        console2.log("=================================");
        console2.log("EscrowFactory deployed to:", address(factory));
        console2.log("USDC address:", usdc);
        console2.log("=================================");

        vm.stopBroadcast();
    }

    /// @notice Deploy EscrowFactory to Base Sepolia.
    function runTestnet() external {
        vm.startBroadcast();

        EscrowFactory factory = new EscrowFactory(USDC_BASE_SEPOLIA);

        console2.log("=================================");
        console2.log("EscrowFactory deployed to:", address(factory));
        console2.log("USDC address (Base Sepolia):", USDC_BASE_SEPOLIA);
        console2.log("=================================");

        vm.stopBroadcast();
    }
}
