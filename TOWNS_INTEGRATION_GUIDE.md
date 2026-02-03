# 🚀 Handshake Bot - Step-by-Step Integration

Complete guide to building Handshake escrow bot using Towns official starter.

## Prerequisites

- ✅ Smart contracts deployed on Base Sepolia
- ✅ ABIs extracted (`abi/EscrowFactory.json`, `abi/Escrow.json`)
- ✅ Bun installed ([bun.sh](https://bun.sh))
- ✅ GitHub account
- ✅ Render account (free tier OK)

## Part 1: Setup Bot Project (15 min)

### 1.1 Create Bot from Template

```bash
# Create new bot project
bunx towns-bot init handshake-bot
cd handshake-bot
bun install
```

This creates:
```
handshake-bot/
├── src/
│   ├── index.ts      # Main bot logic
│   └── commands.ts   # Command definitions
├── AGENTS.md         # AI agent documentation
├── README.md         # Deployment guide
└── package.json
```

### 1.2 Add Dependencies

```bash
# Add viem for blockchain interaction
bun add viem

# Add better-sqlite3 for database
bun add better-sqlite3
```

### 1.3 Register Bot in Developer Portal

1. Go to https://app.towns.com/developer/dashboard
2. Click "Create New Bot"
3. Name: "Handshake Escrow"
4. Save these credentials:
   - `APP_PRIVATE_DATA`
   - `JWT_SECRET`
   - `MNEMONIC`

⚠️ **Never commit these to GitHub!**

## Part 2: Add Escrow Contracts Integration (1 hour)

### 2.1 Add Contract Config

Create `src/config.ts`:

```typescript
import { base } from 'viem/chains';

export const config = {
  // Contract addresses (update after deployment)
  FACTORY_ADDRESS: "0x..." as `0x${string}`,
  USDC_ADDRESS: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913" as `0x${string}`,
  
  // Chain config
  chain: base,
  
  // RPC URL
  rpcUrl: process.env.BASE_RPC_URL || "https://mainnet.base.org",
};
```

### 2.2 Add Contract ABIs

Create `src/abis/` folder and add:

**`src/abis/EscrowFactory.json`** - Copy from contracts/abi/EscrowFactory.json
**`src/abis/Escrow.json`** - Copy from contracts/abi/Escrow.json

### 2.3 Setup Blockchain Client

Create `src/blockchain.ts`:

```typescript
import { createPublicClient, createWalletClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { config } from './config';

// Read-only client for querying
export const publicClient = createPublicClient({
  chain: config.chain,
  transport: http(config.rpcUrl),
});

// Bot's wallet for creating escrows
const account = privateKeyToAccount(
  process.env.BOT_PRIVATE_KEY as `0x${string}`
);

export const walletClient = createWalletClient({
  account,
  chain: config.chain,
  transport: http(config.rpcUrl),
});
```

### 2.4 Setup Database

Create `src/database.ts`:

```typescript
import Database from 'better-sqlite3';

const db = new Database('handshake.db');

// Create tables
db.exec(`
  CREATE TABLE IF NOT EXISTS deals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    escrow_address TEXT UNIQUE NOT NULL,
    deal_id INTEGER NOT NULL,
    town_id TEXT NOT NULL,
    channel_id TEXT,
    message_id TEXT,
    buyer TEXT NOT NULL,
    seller TEXT NOT NULL,
    amount TEXT NOT NULL,
    token TEXT NOT NULL,
    deadline INTEGER NOT NULL,
    arbiter TEXT,
    memo TEXT,
    status TEXT NOT NULL DEFAULT 'CREATED',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  );

  CREATE INDEX IF NOT EXISTS idx_town_id ON deals(town_id);
  CREATE INDEX IF NOT EXISTS idx_buyer ON deals(buyer);
  CREATE INDEX IF NOT EXISTS idx_seller ON deals(seller);
  CREATE INDEX IF NOT EXISTS idx_status ON deals(status);
`);

export interface Deal {
  id?: number;
  escrow_address: string;
  deal_id: number;
  town_id: string;
  channel_id?: string;
  message_id?: string;
  buyer: string;
  seller: string;
  amount: string;
  token: string;
  deadline: number;
  arbiter?: string;
  memo?: string;
  status: string;
  created_at: number;
  updated_at: number;
}

// Insert deal
export function insertDeal(deal: Deal) {
  const stmt = db.prepare(`
    INSERT INTO deals (
      escrow_address, deal_id, town_id, channel_id, message_id,
      buyer, seller, amount, token, deadline, arbiter, memo,
      status, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  
  return stmt.run(
    deal.escrow_address,
    deal.deal_id,
    deal.town_id,
    deal.channel_id,
    deal.message_id,
    deal.buyer,
    deal.seller,
    deal.amount,
    deal.token,
    deal.deadline,
    deal.arbiter,
    deal.memo,
    deal.status,
    deal.created_at,
    deal.updated_at
  );
}

// Get deal by address
export function getDeal(escrowAddress: string): Deal | undefined {
  const stmt = db.prepare('SELECT * FROM deals WHERE escrow_address = ?');
  return stmt.get(escrowAddress) as Deal | undefined;
}

// Update deal status
export function updateDealStatus(escrowAddress: string, status: string) {
  const stmt = db.prepare(`
    UPDATE deals 
    SET status = ?, updated_at = ? 
    WHERE escrow_address = ?
  `);
  return stmt.run(status, Date.now(), escrowAddress);
}

// Get deals by user
export function getDealsByUser(userAddress: string, role: 'buyer' | 'seller') {
  const stmt = db.prepare(`
    SELECT * FROM deals 
    WHERE ${role} = ? 
    ORDER BY created_at DESC 
    LIMIT 20
  `);
  return stmt.all(userAddress) as Deal[];
}

export default db;
```

## Part 3: Implement Commands (2 hours)

### 3.1 Update `src/commands.ts`

```typescript
import type { Command } from '@towns-protocol/bot-sdk';

export const commands: Command[] = [
  {
    name: 'deal',
    description: 'Manage escrow deals',
    subcommands: [
      {
        name: 'create',
        description: 'Create a new escrow deal',
        options: [
          {
            name: 'seller',
            description: 'Address or @mention of seller',
            type: 'string',
            required: true,
          },
          {
            name: 'amount',
            description: 'Amount in USDC',
            type: 'number',
            required: true,
          },
          {
            name: 'description',
            description: 'What is being sold/delivered',
            type: 'string',
            required: true,
          },
          {
            name: 'hours',
            description: 'Deadline in hours (default: 48)',
            type: 'number',
            required: false,
          },
          {
            name: 'arbiter',
            description: 'Optional arbiter address or @mention',
            type: 'string',
            required: false,
          },
        ],
      },
      {
        name: 'list',
        description: 'List your deals',
        options: [
          {
            name: 'filter',
            description: 'Filter by status',
            type: 'string',
            required: false,
            choices: ['all', 'active', 'completed'],
          },
        ],
      },
      {
        name: 'info',
        description: 'Get deal details',
        options: [
          {
            name: 'deal_id',
            description: 'Deal ID or escrow address',
            type: 'string',
            required: true,
          },
        ],
      },
    ],
  },
];
```

### 3.2 Update `src/index.ts` - Add Command Handlers

```typescript
import { Bot } from '@towns-protocol/bot-sdk';
import { commands } from './commands';
import { handleCreateDeal, handleListDeals, handleDealInfo } from './handlers';

const bot = new Bot({
  privateData: process.env.APP_PRIVATE_DATA!,
  jwtSecret: process.env.JWT_SECRET!,
});

// Register commands
bot.registerCommands(commands);

// Handle slash commands
bot.onCommand('deal create', async (interaction) => {
  await handleCreateDeal(interaction);
});

bot.onCommand('deal list', async (interaction) => {
  await handleListDeals(interaction);
});

bot.onCommand('deal info', async (interaction) => {
  await handleDealInfo(interaction);
});

// Handle mentions
bot.onMessage(async (message) => {
  if (message.mentions?.includes(bot.address)) {
    await message.reply({
      text: "👋 I help you make safe deals! Try `/deal create`",
    });
  }
});

// Start bot
const PORT = process.env.PORT || 5123;
bot.start(PORT);

console.log(`🤝 Handshake bot running on port ${PORT}`);
```

### 3.3 Create `src/handlers.ts`

```typescript
import type { CommandInteraction } from '@towns-protocol/bot-sdk';
import { publicClient, walletClient } from './blockchain';
import { config } from './config';
import { insertDeal, getDealsByUser, getDeal } from './database';
import factoryAbi from './abis/EscrowFactory.json';
import { parseEther, keccak256, toHex } from 'viem';

export async function handleCreateDeal(interaction: CommandInteraction) {
  const { options, user, townId, channelId } = interaction;
  
  // Parse options
  const seller = options.seller as string;
  const amount = options.amount as number;
  const description = options.description as string;
  const hours = (options.hours as number) || 48;
  const arbiter = options.arbiter as string | undefined;
  
  // Convert amount to USDC (6 decimals)
  const amountUsdc = BigInt(amount * 1_000_000);
  
  // Calculate deadline
  const deadline = Math.floor(Date.now() / 1000) + (hours * 3600);
  
  // Hash description
  const memoHash = keccak256(toHex(description));
  
  try {
    // Call factory.createEscrow
    const hash = await walletClient.writeContract({
      address: config.FACTORY_ADDRESS,
      abi: factoryAbi,
      functionName: 'createEscrow',
      args: [
        seller as `0x${string}`,
        config.USDC_ADDRESS,
        amountUsdc,
        BigInt(deadline),
        arbiter ? (arbiter as `0x${string}`) : '0x0000000000000000000000000000000000000000',
        memoHash,
      ],
    });
    
    // Wait for transaction
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    
    // Parse EscrowCreated event to get escrow address and ID
    const log = receipt.logs.find(
      (log) => log.topics[0] === keccak256(toHex('EscrowCreated(address,uint256,address,address,address,uint256,uint256,address,bytes32)'))
    );
    
    if (!log) throw new Error('EscrowCreated event not found');
    
    const escrowAddress = `0x${log.topics[1]!.slice(-40)}`;
    const dealId = parseInt(log.topics[2]!, 16);
    
    // Save to database
    insertDeal({
      escrow_address: escrowAddress,
      deal_id: dealId,
      town_id: townId,
      channel_id: channelId,
      buyer: user.address,
      seller,
      amount: amount.toString(),
      token: config.USDC_ADDRESS,
      deadline,
      arbiter,
      memo: description,
      status: 'CREATED',
      created_at: Date.now(),
      updated_at: Date.now(),
    });
    
    // Send deal card
    await interaction.reply({
      text: `✅ Deal #${dealId} created!`,
      embeds: [{
        title: `🤝 Escrow Deal #${dealId}`,
        description: description,
        fields: [
          { name: 'Buyer', value: user.address, inline: true },
          { name: 'Seller', value: seller, inline: true },
          { name: 'Amount', value: `${amount} USDC`, inline: true },
          { name: 'Deadline', value: `${hours}h`, inline: true },
          { name: 'Status', value: '⏳ AWAITING FUNDING', inline: true },
        ],
        footer: { text: `Escrow: ${escrowAddress}` },
      }],
      components: [{
        type: 'button',
        label: 'Open Deal',
        url: `https://handshake-miniapp.vercel.app/deal/${escrowAddress}`,
      }],
    });
    
  } catch (error) {
    console.error('Create deal error:', error);
    await interaction.reply({
      text: `❌ Failed to create deal: ${error.message}`,
      ephemeral: true,
    });
  }
}

export async function handleListDeals(interaction: CommandInteraction) {
  const { user, options } = interaction;
  const filter = options.filter as string || 'all';
  
  // Get user's deals (as buyer or seller)
  const buyerDeals = getDealsByUser(user.address, 'buyer');
  const sellerDeals = getDealsByUser(user.address, 'seller');
  
  const allDeals = [...buyerDeals, ...sellerDeals];
  
  if (allDeals.length === 0) {
    return interaction.reply({
      text: "You don't have any deals yet. Create one with `/deal create`!",
      ephemeral: true,
    });
  }
  
  // Format deals
  const dealsList = allDeals.map((deal) => {
    const role = deal.buyer === user.address ? 'Buyer' : 'Seller';
    return `**#${deal.deal_id}** - ${deal.amount} USDC - ${deal.status} - *${role}*`;
  }).join('\n');
  
  await interaction.reply({
    text: `📋 Your Deals:\n\n${dealsList}`,
    ephemeral: true,
  });
}

export async function handleDealInfo(interaction: CommandInteraction) {
  const { options } = interaction;
  const dealIdOrAddress = options.deal_id as string;
  
  // Try to get deal
  const deal = getDeal(dealIdOrAddress);
  
  if (!deal) {
    return interaction.reply({
      text: `❌ Deal not found: ${dealIdOrAddress}`,
      ephemeral: true,
    });
  }
  
  await interaction.reply({
    text: `ℹ️ Deal #${deal.deal_id}`,
    embeds: [{
      title: `Deal #${deal.deal_id}`,
      description: deal.memo,
      fields: [
        { name: 'Buyer', value: deal.buyer },
        { name: 'Seller', value: deal.seller },
        { name: 'Amount', value: `${deal.amount} USDC` },
        { name: 'Status', value: deal.status },
        { name: 'Escrow', value: deal.escrow_address },
      ],
    }],
  });
}
```

## Part 4: Add Event Listeners (1 hour)

Create `src/events.ts`:

```typescript
import { publicClient } from './blockchain';
import { config } from './config';
import { updateDealStatus, getDeal } from './database';
import escrowAbi from './abis/Escrow.json';
import { parseAbiItem } from 'viem';

// Watch for Funded events
export function watchFundedEvents() {
  publicClient.watchEvent({
    address: config.FACTORY_ADDRESS,
    event: parseAbiItem('event Funded(uint256 amount, uint256 timestamp)'),
    onLogs: async (logs) => {
      for (const log of logs) {
        const escrowAddress = log.address;
        const deal = getDeal(escrowAddress);
        
        if (deal) {
          updateDealStatus(escrowAddress, 'FUNDED');
          console.log(`✅ Deal #${deal.deal_id} funded`);
          // TODO: Update message in Towns
        }
      }
    },
  });
}

// Watch for Released events
export function watchReleasedEvents() {
  publicClient.watchEvent({
    event: parseAbiItem('event Released(uint256 amount, uint256 timestamp)'),
    onLogs: async (logs) => {
      for (const log of logs) {
        const escrowAddress = log.address;
        const deal = getDeal(escrowAddress);
        
        if (deal) {
          updateDealStatus(escrowAddress, 'RELEASED');
          console.log(`✅ Deal #${deal.deal_id} released`);
          // TODO: Send receipt message
        }
      }
    },
  });
}

// Start all watchers
export function startEventWatchers() {
  watchFundedEvents();
  watchReleasedEvents();
  // Add more watchers...
  
  console.log('📡 Event watchers started');
}
```

Add to `src/index.ts`:
```typescript
import { startEventWatchers } from './events';

// After bot.start()
startEventWatchers();
```

## Part 5: Deploy (30 min)

### 5.1 Push to GitHub

```bash
git init
git add .
git commit -m "Initial Handshake bot"
gh repo create handshake-bot --public --source=. --push
```

### 5.2 Deploy on Render

1. Go to [render.com](https://render.com)
2. New → Web Service
3. Connect GitHub repo: `handshake-bot`
4. Settings:
   - Name: `handshake-bot`
   - Environment: `Node`
   - Build: `bun install`
   - Start: `bun run start`
   - Environment variables:
     - `APP_PRIVATE_DATA` = [from developer portal]
     - `JWT_SECRET` = [from developer portal]
     - `PORT` = `5123`
     - `BASE_RPC_URL` = `https://mainnet.base.org`
     - `BOT_PRIVATE_KEY` = [wallet for signing txs]
5. Click "Create Web Service"

### 5.3 Configure Webhook

1. Go to https://app.towns.com/developer
2. Find your bot → Edit
3. Webhook URL: `https://handshake-bot.onrender.com/webhook`
4. Message forwarding: "Mentions, Replies, Reactions, Slash Commands"
5. Save

### 5.4 Add Discovery Endpoint

Add to `src/index.ts`:
```typescript
bot.app.get('/.well-known/agent-metadata.json', async (c) => {
  return c.json(await bot.getIdentityMetadata());
});
```

Redeploy and click "Boost" in developer portal.

## Part 6: Test (15 min)

1. Install bot in your test Town
2. Go to a channel
3. Test commands:
   ```
   /deal create @friend 10 USDC "Test deal" 1
   /deal list
   /deal info 0x...
   ```
4. Check bot responds correctly
5. Check database has deal
6. Check Render logs for errors

## Next Steps

- [ ] Build miniapp for fund/release UI
- [ ] Add more event handlers
- [ ] Add error handling
- [ ] Add tests
- [ ] Polish messages
- [ ] Add analytics

## Troubleshooting

**Bot not responding?**
- Check Render logs
- Verify webhook URL ends with `/webhook`
- Check environment variables

**Contract calls failing?**
- Verify contract addresses in config
- Check BOT_PRIVATE_KEY has gas
- Test on Sepolia first

**Database errors?**
- Check `handshake.db` is created
- Verify SQL schema

---

**You now have a working Handshake bot!** 🎉
