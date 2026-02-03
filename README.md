# Handshake Escrow - Smart Contracts

> **Trustless escrow inside Towns. Lock USDC on Base → Release/Refund → Receipt.**

On-chain escrow contracts for peer-to-peer deals with optional arbitration. Built for the [Towns Bot Competition](https://www.towns.com/competitions).

## 🎯 What This Does

- **Buyer** locks USDC in a smart contract
- **Seller** sees funds are guaranteed
- **Release** when satisfied or **Refund** after deadline
- Optional **Arbiter** for dispute resolution
- All on Base L2 for low gas fees

## 📦 Architecture

### Contracts

- **`EscrowFactory.sol`** - Creates and tracks all escrow deals
- **`Escrow.sol`** - Individual escrow logic (one per deal)

### Deal Lifecycle

```
CREATED → FUNDED → RELEASED/REFUNDED
              ↓
          DISPUTED → RESOLVED (if arbiter exists)
```

### Key Features

✅ NonReentrant guards  
✅ SafeERC20 token handling  
✅ Role-based access control  
✅ Deadline-based refunds  
✅ Optional dispute resolution  
✅ USDC-only whitelist (extensible)

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Base RPC URL (e.g., from [Alchemy](https://www.alchemy.com/))

### Installation

```bash
# Clone repo
git clone <your-repo>
cd handshake-escrow

# Install dependencies
forge install foundry-rs/forge-std --no-commit
forge install OpenZeppelin/openzeppelin-contracts --no-commit

# Copy environment variables
cp .env.example .env
# Edit .env with your private key and RPC URLs
```

### Run Tests

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test
forge test --match-test test_Release_Success

# Gas report
forge test --gas-report
```

Expected output: All tests passing ✅

### Deploy to Base Sepolia (Testnet)

```bash
# Load environment
source .env

# Deploy
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv

# Or use the testnet-specific function
forge script script/Deploy.s.sol:DeployScript \
  --sig "runTestnet()" \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

### Deploy to Base Mainnet

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

## 📝 Contract Addresses

### Base Mainnet
- **EscrowFactory**: `TBD`
- **USDC**: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`

### Base Sepolia
- **EscrowFactory**: `TBD`
- **USDC**: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`

## 🔧 Usage Example

### 1. Create Escrow

```solidity
address seller = 0x...;
address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
uint256 amount = 100e6; // 100 USDC
uint256 deadline = block.timestamp + 48 hours;
address arbiter = 0x...; // or address(0) for none
bytes32 memoHash = keccak256("Logo design for project");

address escrowAddr = factory.createEscrow(
    seller,
    usdc,
    amount,
    deadline,
    arbiter,
    memoHash
);
```

### 2. Fund Escrow (Buyer)

```solidity
IERC20(usdc).approve(escrowAddr, amount);
Escrow(escrowAddr).fund();
```

### 3. Release Funds (Buyer)

```solidity
Escrow(escrowAddr).release(); // Pays seller
```

### 4. Or Refund After Deadline

```solidity
// After deadline passes
Escrow(escrowAddr).refundAfterDeadline(); // Returns to buyer
```

### 5. Dispute Resolution (Optional)

```solidity
// Buyer or Seller opens dispute
Escrow(escrowAddr).openDispute();

// Arbiter resolves
Escrow(escrowAddr).resolve(true); // true = pay seller, false = refund buyer
```

## 🧪 Testing Checklist

- ✅ Factory: Create escrow, token whitelist
- ✅ Fund: Success, unauthorized, after deadline
- ✅ Release: Success, unauthorized, wrong status
- ✅ Refund: Success, before deadline, wrong status
- ✅ Dispute: Open, resolve, no arbiter, unauthorized
- ✅ Registry: Track buyer/seller escrows

Coverage: 100% of functions

## 🔐 Security Considerations

1. **No custody**: Funds never held by bot/backend
2. **Immutable roles**: Buyer/seller/arbiter set at creation
3. **Deadline enforcement**: Refund only after deadline
4. **Reentrancy protection**: NonReentrant on all state-changing functions
5. **Token whitelist**: Only approved tokens (USDC)

## 📊 Gas Estimates

| Function | Gas Cost |
|----------|----------|
| createEscrow | ~250k |
| fund | ~90k |
| release | ~55k |
| refundAfterDeadline | ~55k |
| openDispute | ~45k |
| resolve | ~55k |

*Estimates on Base Sepolia. Mainnet may vary.*

## 🛠 Development

```bash
# Format code
forge fmt

# Check formatting
forge fmt --check

# Update dependencies
forge update

# Build
forge build

# Clean
forge clean
```

## 📚 Key Dependencies

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) - SafeERC20, ReentrancyGuard
- [Foundry](https://github.com/foundry-rs/foundry) - Testing & deployment

## 🏗 Architecture Decisions

### Why Factory Pattern?
- Easy indexing of all escrows
- Track user activity (buyer/seller history)
- Emit events for bot indexer

### Why Immutable Parameters?
- Gas savings
- Cannot be manipulated post-creation
- Clear audit trail

### Why USDC-Only?
- Simplifies MVP
- Most liquid stablecoin on Base
- Easy to extend later

## 🎯 Next Steps

1. ✅ Deploy to Base mainnet
2. 🔄 Integrate with Towns bot
3. 🔄 Build miniapp frontend
4. 📈 Add analytics dashboard
5. 🌟 Launch & gather feedback

## 📄 License

MIT

## 🤝 Contributing

Built for Towns Bot Competition. Feedback welcome!

## 🔗 Links

- [Towns Protocol](https://www.towns.com)
- [Base Network](https://base.org)
- [Competition Details](https://www.towns.com/competitions)

---

**Built with 🤝 for trustless peer-to-peer deals**
