// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/EscrowFactory.sol";

contract UpdateConfigScript is Script {
    function run() external {
        address factoryAddress = 0xFeDD8d8DCa1d09d517407C8F548B611656Cb2363;
        
        vm.startBroadcast();

        EscrowFactory factory = EscrowFactory(factoryAddress);
        
        // 1. Set correct TOWNS address on Base
        factory.setFeeToken(0x00000000A22cB18fd6b4D7E9a335c4b96b189a38);
        
        // 2. Set optimal pool fee (0.3% = 3000)
        factory.setDefaultPoolFee(3000);

        vm.stopBroadcast();
    }
}
