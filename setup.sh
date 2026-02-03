#!/bin/bash
set -e

echo "🤝 Handshake Escrow - Setup Script"
echo "=================================="

# Ensure git repo exists (forge install uses submodules)
if [ ! -d .git ]; then
    echo "📁 Initializing git repo (required for forge install)..."
    git init >/dev/null
fi

# Check if foundry is installed
if ! command -v forge &> /dev/null; then
    echo "❌ Foundry not found. Installing..."
    curl -L https://foundry.paradigm.xyz | bash
    foundryup
else
    echo "✅ Foundry found"
fi

# Install dependencies
echo ""
echo "📦 Installing dependencies..."

set +e
forge install foundry-rs/forge-std --no-commit
STD1=$?
forge install OpenZeppelin/openzeppelin-contracts --no-commit
STD2=$?
set -e

if [ $STD1 -ne 0 ] || [ $STD2 -ne 0 ]; then
    echo "ℹ️  Your Foundry version may not support --no-commit. Retrying without it..."
    forge install foundry-rs/forge-std
    forge install OpenZeppelin/openzeppelin-contracts
fi

# Build contracts
echo ""
echo "🔨 Building contracts..."
forge build

# Run tests
echo ""
echo "🧪 Running tests..."
forge test

echo ""
echo "=================================="
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. (Recommended) Import a deployer key into Foundry keystore with: cast wallet import <name>"
echo "2. Run 'forge test' to verify everything works"
echo "3. Deploy with 'forge script script/Deploy.s.sol --broadcast --account <name>'"
echo "=================================="
