# ⚡ Quick Start Guide

Get Handshake Escrow running in 5 minutes.

## Prerequisites

```bash
# Install Foundry (if not installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Setup

```bash
# 1. Install dependencies
forge install foundry-rs/forge-std --no-commit
forge install OpenZeppelin/openzeppelin-contracts --no-commit

# 2. Build contracts
forge build

# 3. Run tests
forge test
```

You should see: **All tests passing ✅**

## Deploy to Base Sepolia (Testnet)

```bash
# 1. Setup environment
cp .env.example .env
nano .env  # Add your PRIVATE_KEY and BASE_SEPOLIA_RPC_URL

# 2. Deploy
source .env
forge script script/Deploy.s.sol:DeployScript \
  --sig "runTestnet()" \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify

# 3. Save the deployed factory address
```

## Test a Deal (on testnet)

```bash
# Use cast to interact with your deployed factory

# 1. Get Base Sepolia USDC
# Visit https://faucet.circle.com/

# 2. Create an escrow
cast send <FACTORY_ADDRESS> \
  "createEscrow(address,address,uint256,uint256,address,bytes32)" \
  <SELLER_ADDRESS> \
  0x036CbD53842c5426634e7929541eC2318f3dCF7e \
  100000000 \
  $(($(date +%s) + 3600)) \
  0x0000000000000000000000000000000000000000 \
  $(cast keccak "test deal") \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 3. Note the escrow address from logs
# 4. Approve USDC
cast send 0x036CbD53842c5426634e7929541eC2318f3dCF7e \
  "approve(address,uint256)" \
  <ESCROW_ADDRESS> \
  100000000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 5. Fund escrow
cast send <ESCROW_ADDRESS> \
  "fund()" \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 6. Release to seller
cast send <ESCROW_ADDRESS> \
  "release()" \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

## What's Next?

1. ✅ Contracts deployed
2. 🔄 Build the Towns bot (next step)
3. 🔄 Create miniapp UI
4. 🚀 Launch!

## Need Help?

Check the full [README.md](./README.md) for detailed documentation.
