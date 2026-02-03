# 🤖 Handshake Bot - Development Plan (Updated)

## Изменения в подходе

**Было:** Писать бота с нуля на Node.js + Towns SDK
**Стало:** Использовать официальный стартер `bunx towns-bot init` + добавить escrow логику

**Преимущества:**
- ✅ Готовая инфраструктура (webhook, команды, deploy)
- ✅ Официальный паттерн от Towns
- ✅ Документация AGENTS.md в проекте
- ✅ Простой деплой на Render
- ✅ Меньше времени на setup, больше на функционал

## Обновленный план разработки

### День 1 (сегодня) - Smart Contracts ✅
- ✅ EscrowFactory.sol + Escrow.sol
- ✅ Тесты 100% coverage
- ✅ Deploy скрипты
- [ ] Deploy на Base Sepolia
- [ ] Extract ABIs

### День 2 (завтра) - Bot + Integration

#### Утро: Setup бота (30 мин)

```bash
# 1. Создать бот проект
bunx towns-bot init handshake-bot
cd handshake-bot
bun install

# 2. Зарегистрировать бота в Developer Portal
# https://app.towns.com/developer/dashboard
# Сохранить: APP_PRIVATE_DATA, JWT_SECRET, MNEMONIC

# 3. Добавить зависимости для работы с контрактами
bun add viem
```

#### День: Добавить escrow функционал (4-5 часов)

**Что добавляем в бот:**

1. **Команды** (`src/commands.ts`):
   ```typescript
   /deal create @seller 50 USDC "Logo design" 48h [@arbiter]
   /deal list [mine|all]
   /deal info <dealId>
   /deal help
   ```

2. **Обработчики сообщений** (`src/index.ts`):
   - Парсинг команд
   - Вызовы factory.createEscrow()
   - Чтение статусов сделок
   - Отправка deal cards в чат

3. **Event listeners**:
   - Слушать Funded/Released/Refunded events
   - Автообновление deal cards
   - Отправка уведомлений

4. **Database** (SQLite):
   ```sql
   CREATE TABLE deals (
     id INTEGER PRIMARY KEY,
     escrow_address TEXT UNIQUE,
     town_id TEXT,
     message_id TEXT,
     buyer TEXT,
     seller TEXT,
     amount TEXT,
     status TEXT,
     created_at INTEGER
   );
   ```

5. **Config файл** (contract addresses, ABIs):
   ```typescript
   // src/config.ts
   export const FACTORY_ADDRESS = "0x...";
   export const USDC_ADDRESS = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
   ```

#### Вечер: Deploy + тестирование (2 часа)

```bash
# 1. Push to GitHub
git init
git add .
git commit -m "Handshake escrow bot"
gh repo create handshake-bot --public --source=. --push

# 2. Deploy на Render
# - New Web Service
# - Build: bun install
# - Start: bun run start
# - ENV: APP_PRIVATE_DATA, JWT_SECRET, PORT=5123

# 3. Configure webhook
# https://app.towns.com/developer → Edit bot
# Webhook: https://handshake-bot.onrender.com/webhook

# 4. Install bot в test town
# Протестировать команды
```

### День 3 (послезавтра) - Miniapp + Polish

#### Утро: Miniapp для deal cards (3 часа)

**Создать Next.js miniapp:**
```bash
npx create-next-app@latest handshake-miniapp
cd handshake-miniapp
npm install wagmi viem @rainbow-me/rainbowkit
```

**Страница deal:** `/deal/[address]`
- Read-only статус (buyer, seller, amount, status)
- Кнопки: Approve, Fund, Release, Refund, Dispute, Resolve
- Connect wallet (Coinbase Wallet)
- Transaction confirmations

**Deploy miniapp:**
- Vercel или Render
- URL: https://handshake-miniapp.vercel.app

**Интеграция с ботом:**
Бот шарит miniapp как attachment к deal card:
```typescript
await bot.sendMessage({
  text: "Deal #42 created",
  attachments: [{
    type: "miniapp",
    url: `https://handshake-miniapp.vercel.app/deal/${escrowAddress}`
  }]
});
```

#### День: UI polish + видео (3 часа)

**Брендинг:**
- Logo: 🤝🔒
- Colors: Dark theme + Base blue
- Banner 1200x400
- Icon 512x512

**Demo видео (60-90 сек):**
1. Open Towns channel
2. Type `/deal create @seller 50 USDC "CS2 skins" 48h`
3. Bot posts deal card
4. Click "Open Deal" → miniapp
5. Connect wallet → Fund
6. Show "Funded" status
7. Release to seller
8. Show receipt + Basescan link
9. End screen: "Handshake - Safe deals in Towns"

**Скрины:**
- Deal card in chat
- Miniapp funding screen
- Miniapp release confirmation
- Receipt message

#### Вечер: Submission (2 часа)

**Собрать материалы:**
- ✅ Demo video uploaded
- ✅ 3-5 screenshots
- ✅ GitHub repos (contracts + bot + miniapp)
- ✅ Deployed addresses
- ✅ How to try instructions

**Submission text:**

**Short (100 chars):**
"Trustless peer-to-peer escrow in Towns. Lock USDC on Base → Release/Refund → Receipt in chat."

**Long (500 words):**
```
Handshake brings trustless escrow to Towns communities.

THE PROBLEM:
Towns communities constantly make deals - design work, OTC trades, 
bounties, services. But there's no built-in trust layer, leading to:
- Scams and ghosting
- Money sent outside the chat
- No dispute resolution
- Lost time and broken trust

HANDSHAKE SOLVES THIS:
Safe peer-to-peer deals directly in chat, powered by Base smart contracts.

HOW IT WORKS:
1. Buyer creates deal: `/deal create @seller 50 USDC "Logo design" 48h`
2. Buyer funds escrow (USDC locked on Base)
3. Seller delivers work
4. Buyer releases funds OR refunds after deadline
5. Optional: Arbiter resolves disputes

KEY FEATURES:
✅ Zero custody - funds in smart contract
✅ Deadline protection - auto-refund available
✅ Optional arbitration - Town admin can resolve disputes
✅ Full transparency - all transactions on Base
✅ Receipts in chat - Basescan links for every action

TECHNICAL STACK:
- Smart Contracts: Solidity (Foundry)
- Bot: Towns SDK + Bun
- Miniapp: Next.js + wagmi + viem
- Chain: Base L2 (low gas fees)

WHY THIS WINS "BOTS THAT MOVE MONEY":
- Actually moves USDC on-chain
- Solves real community pain
- Production-ready code
- Extensible foundation

USE CASES:
- OTC trades
- Freelance services
- Community bounties
- Peer-to-peer sales
- Collaborative funding

TRY IT:
1. Install Handshake bot in your Town
2. Type `/deal create @friend 10 USDC "Test deal" 1h`
3. Fund via miniapp
4. Release or refund

CONTRACT: 0x... (Base)
DEMO: [video link]
CODE: github.com/...
```

**Submit to:**
- https://www.towns.com/competitions
- Tweet with video + tag @townsapp
- Farcaster post
- Discord announcement

**Community votes:**
- Ask friends to install and test
- Share in crypto communities
- Post in Towns developer town

## Быстрая проверка готовности

**Before starting Day 2:**
```bash
# Contracts deployed?
cast call $FACTORY_ADDRESS "getEscrowCount()" --rpc-url $BASE_SEPOLIA_RPC_URL

# ABIs extracted?
ls abi/EscrowFactory.json abi/Escrow.json

# Bot registered?
# Check https://app.towns.com/developer/dashboard
```

**Before starting Day 3:**
```bash
# Bot responding?
# Test: @handshake /deal help

# Events working?
# Check Render logs for "Event: Funded"

# Database working?
# Check: bun run "SELECT * FROM deal"
```

## Adjustments from Original Plan

**Что изменилось:**
- ❌ НЕ пишем бот с нуля
- ✅ Используем `towns-bot init`
- ✅ Добавляем только escrow логику
- ✅ Используем их webhook/deploy паттерн
- ✅ Следуем AGENTS.md в проекте

**Что осталось:**
- ✅ Smart contracts как есть
- ✅ Miniapp на Next.js
- ✅ Integration с viem
- ✅ Database для state
- ✅ Event listeners

**Экономия времени:**
- Setup бота: с 3 часов → 30 минут
- Deploy: с 2 часов → 30 минут
- Debugging: меньше, т.к. используем проверенный стартер

**Итого:** Больше времени на escrow логику и UI polish = лучший продукт!

## Resources

**Official Towns:**
- Tutorial: https://www.towns.com/academy/vibebot
- Docs: https://docs.towns.com/build/bots
- Developer Portal: https://app.towns.com/developer

**Our Repos:**
- Contracts: github.com/.../handshake-contracts
- Bot: github.com/.../handshake-bot
- Miniapp: github.com/.../handshake-miniapp

**Deploy:**
- Contracts: Base Sepolia/Mainnet
- Bot: Render (https://handshake-bot.onrender.com)
- Miniapp: Vercel (https://handshake-miniapp.vercel.app)
