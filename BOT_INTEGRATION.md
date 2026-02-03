# 🤖 Bot Integration Guide

How to integrate Handshake Escrow contracts with your Towns bot using the official Towns bot starter.

## Important: Use Towns Official Starter

**Don't build from scratch!** Towns provides an official bot starter template:

```bash
bunx towns-bot init handshake-bot
cd handshake-bot
bun install
```

This gives you:
- ✅ Pre-configured webhook endpoint
- ✅ Command system
- ✅ Message handlers
- ✅ Deploy-ready structure
- ✅ AGENTS.md documentation

**Official tutorial:** https://www.towns.com/academy/vibebot

This guide shows how to **add escrow functionality** to the Towns starter template.

## Overview

The bot needs to:
1. Listen to commands (`/deal create`, etc.)
2. Call smart contract functions
3. Listen to contract events
4. Update deal cards in chat

## Contract Addresses

```typescript
// Base Mainnet
const FACTORY_ADDRESS = "0x..."; // Deploy and update this
const USDC_ADDRESS = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";

// Base Sepolia
const FACTORY_ADDRESS_TESTNET = "0x...";
const USDC_ADDRESS_TESTNET = "0x036CbD53842c5426634e7929541eC2318f3dCF7e";
```

## Setup Web3 Client

```typescript
import { createPublicClient, createWalletClient, http } from 'viem';
import { base } from 'viem/chains';

const publicClient = createPublicClient({
  chain: base,
  transport: http(process.env.BASE_RPC_URL),
});

const walletClient = createWalletClient({
  chain: base,
  transport: http(process.env.BASE_RPC_URL),
});
```

## Create Escrow (from bot)

```typescript
import factoryAbi from './abi/EscrowFactory.json';

async function createEscrow(params: {
  seller: string;
  amount: bigint;
  deadline: number;
  arbiter: string;
  memo: string;
}) {
  const memoHash = keccak256(toHex(params.memo));

  const hash = await walletClient.writeContract({
    address: FACTORY_ADDRESS,
    abi: factoryAbi,
    functionName: 'createEscrow',
    args: [
      params.seller,
      USDC_ADDRESS,
      params.amount,
      params.deadline,
      params.arbiter,
      memoHash,
    ],
  });

  // Wait for transaction
  const receipt = await publicClient.waitForTransactionReceipt({ hash });

  // Parse EscrowCreated event
  const log = receipt.logs.find(
    (log) => log.topics[0] === keccak256(toHex('EscrowCreated(...)'))
  );

  const escrowAddress = `0x${log.topics[1].slice(-40)}`;
  return { escrowAddress, txHash: hash };
}
```

## Listen to Events

```typescript
import escrowAbi from './abi/Escrow.json';

// Watch for Funded events
publicClient.watchContractEvent({
  address: escrowAddress,
  abi: escrowAbi,
  eventName: 'Funded',
  onLogs: (logs) => {
    logs.forEach((log) => {
      console.log('Escrow funded:', log.args);
      // Update deal card in Towns
      updateDealCard(escrowAddress, { status: 'FUNDED' });
    });
  },
});

// Watch for Released events
publicClient.watchContractEvent({
  address: escrowAddress,
  abi: escrowAbi,
  eventName: 'Released',
  onLogs: (logs) => {
    // Update deal card: RELEASED
  },
});
```

## Read Escrow Status

```typescript
async function getDealInfo(escrowAddress: string) {
  const result = await publicClient.readContract({
    address: escrowAddress,
    abi: escrowAbi,
    functionName: 'getDealInfo',
  });

  return {
    buyer: result[0],
    seller: result[1],
    token: result[2],
    amount: result[3],
    deadline: result[4],
    arbiter: result[5],
    memoHash: result[6],
    status: result[7], // 0=CREATED, 1=FUNDED, etc.
    fundedAt: result[8],
  };
}
```

## User Actions (via Miniapp)

The miniapp will handle user signatures:

```typescript
// User approves USDC
await walletClient.writeContract({
  address: USDC_ADDRESS,
  abi: erc20Abi,
  functionName: 'approve',
  args: [escrowAddress, amount],
});

// User funds escrow
await walletClient.writeContract({
  address: escrowAddress,
  abi: escrowAbi,
  functionName: 'fund',
});

// User releases
await walletClient.writeContract({
  address: escrowAddress,
  abi: escrowAbi,
  functionName: 'release',
});
```

## Database Schema (suggested)

```sql
CREATE TABLE deals (
  id INTEGER PRIMARY KEY,
  escrow_address TEXT UNIQUE NOT NULL,
  town_id TEXT NOT NULL,
  message_id TEXT, -- Towns message containing deal card
  buyer TEXT NOT NULL,
  seller TEXT NOT NULL,
  amount TEXT NOT NULL,
  deadline INTEGER NOT NULL,
  arbiter TEXT,
  memo TEXT,
  status TEXT NOT NULL, -- CREATED, FUNDED, RELEASED, etc.
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX idx_town_id ON deals(town_id);
CREATE INDEX idx_buyer ON deals(buyer);
CREATE INDEX idx_seller ON deals(seller);
```

## Event Polling (alternative to WebSocket)

```typescript
async function pollEvents() {
  const latestBlock = await publicClient.getBlockNumber();

  // Get events from last 1000 blocks
  const logs = await publicClient.getLogs({
    address: FACTORY_ADDRESS,
    event: parseAbiItem('event EscrowCreated(...)'),
    fromBlock: latestBlock - 1000n,
    toBlock: latestBlock,
  });

  for (const log of logs) {
    // Process event
  }
}

// Poll every 12 seconds (Base block time)
setInterval(pollEvents, 12000);
```

## Error Handling

```typescript
try {
  await createEscrow(...);
} catch (error) {
  if (error.message.includes('Token not allowed')) {
    return 'USDC only supported';
  }
  if (error.message.includes('Deadline must be in future')) {
    return 'Invalid deadline';
  }
  throw error;
}
```

## Gas Estimation

```typescript
const gasEstimate = await publicClient.estimateContractGas({
  address: escrowAddress,
  abi: escrowAbi,
  functionName: 'fund',
  account: buyerAddress,
});

console.log(`Estimated gas: ${gasEstimate}`);
```

## Next Steps

1. Deploy contracts to Base
2. Extract ABIs: `./extract-abi.sh`
3. Build bot server with Towns SDK
4. Build miniapp with wagmi/viem
5. Connect everything!

## Testing

Use Base Sepolia for development:
- Get testnet ETH from [Base faucet](https://www.coinbase.com/faucets/base-ethereum-goerli-faucet)
- Get USDC from [Circle faucet](https://faucet.circle.com/)

## Resources

- [viem docs](https://viem.sh/)
- [Towns bot docs](https://docs.towns.com/build/bots)
- [Base docs](https://docs.base.org/)
