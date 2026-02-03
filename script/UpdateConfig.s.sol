// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/EscrowFactory.sol";

contract UpdateConfigScript is Script {
    function run() external {
        address factoryAddress = 0xFeDD8d8DCa1d09d517407C8F548B611656Cb2363;
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        EscrowFactory factory = EscrowFactory(factoryAddress);
        
        // 1. Set correct TOWNS address on Base
        factory.setFeeToken(0x00000000A22C618fd6b4D7E9A335C4B96B189a38);
        
        // 2. Set pool fee to 1% (10000) - only tier with USDC/TOWNS liquidity on Base
        factory.setDefaultPoolFee(10000);

        vm.stopBroadcast();
    }
}
