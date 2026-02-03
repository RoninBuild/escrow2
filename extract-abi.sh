#!/bin/bash
# Extract ABIs for bot/miniapp integration

echo "📝 Extracting ABIs..."

# Build first
forge build

# Create abi directory
mkdir -p abi

# Extract Factory ABI
jq '.abi' out/EscrowFactory.sol/EscrowFactory.json > abi/EscrowFactory.json
echo "✅ EscrowFactory ABI → abi/EscrowFactory.json"

# Extract Escrow ABI
jq '.abi' out/Escrow.sol/Escrow.json > abi/Escrow.json
echo "✅ Escrow ABI → abi/Escrow.json"

echo ""
echo "ABIs ready for bot integration!"
