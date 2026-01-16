# Forking Base Chain and Getting USDC

## ✅ Solution Found!

The script works! Use **config-based forking** (FORKING=true), not `--fork` flag.

## Issue with Hardhat v2 and Base Forking

Hardhat v2 uses EDR (Execution Development Runtime) which doesn't have Base's hardfork activation history pre-configured. This causes errors when:
- Using `hardhat node --fork` directly
- Reading balances/calling view functions (triggers hardfork validation)

**Solution**: Use config-based forking which works better with EDR.

## ✅ Working Solution: Use FORKING=true

**This method works!** The script automatically tries multiple USDC whales until one succeeds.

```bash
FORKING=true npx hardhat run scripts/fork/getUSDC.js
```

Or use the npm script:
```bash
npm run fork:usdc
```

**What happens:**
1. Script forks Base using config-based approach (avoids `--fork` flag issues)
2. Skips balance checks (triggers hardfork validation errors)
3. Tries multiple USDC whale addresses
4. Transfers 100 USDC (configurable in script) to your account
5. Currently works with Base system contract at `0x4200000000000000000000000000000000000010`

**Note**: The script transfers 100 USDC by default. You can adjust the amount in `getUSDC.js`:
```javascript
const USDC_AMOUNT = ethers.parseUnits("100", 6); // Change amount here
```

## 🚀 Running Persistent Forked Node for Remix IDE

To run a persistent forked node that Remix IDE can connect to:

### Step 1: Start the Forked Node

**Terminal 1:**
```bash
npm run node:fork
```

Or directly:
```bash
FORKING=true npx hardhat node
```

This starts a Hardhat node forking Base mainnet on `http://127.0.0.1:8545`

### Step 2: Seed USDC to Accounts (in a new terminal)

**Terminal 2:**
```bash
npm run fork:setup
```

Or:
```bash
FORKING=true npx hardhat run scripts/fork/setupForkNode.js
```

This seeds 10,000 USDC to the first 5 Hardhat accounts.

### Step 3: Connect Remix IDE

1. Open Remix IDE at https://remix.ethereum.org
2. Go to **Deploy & Run Transactions** tab
3. Under **Environment**, select **External Http Provider**
4. Enter: `http://127.0.0.1:8545`
5. Click **Connect**
6. You'll see your accounts with USDC balance!

### Quick Start (All in One)

Use the shell script:
```bash
./scripts/fork/startForkedNode.sh
```

### Account Information

The forked node provides these default Hardhat accounts (each with 10,000 ETH and seeded with 10,000 USDC):

1. `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
2. `0x70997970C51812dc3A010C7d01b50e0d17dc79C8`
3. `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC`
4. `0x90F79bf6EB2c4f870365E785982E1f101E93b906`
5. `0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65`

### Troubleshooting

- **Node won't start**: Make sure no other process is using port 8545
- **Remix can't connect**: Check firewall settings, ensure node is running
- **No USDC**: Run the setup script after starting the node

## Getting a Better RPC Endpoint

The public Base RPC (`https://mainnet.base.org`) is rate-limited and may not support archive state. For better results, use:

- **Alchemy**: `https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY`
- **Infura**: `https://base-mainnet.infura.io/v3/YOUR_API_KEY`
- **QuickNode**: Your QuickNode Base endpoint
- **Chainstack**: Your Chainstack Base endpoint

Update your `.env`:
```bash
BASE_RPC_URL=https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY
```

## Troubleshooting

1. **Hardfork errors**: Use Method 1 (separate node)
2. **Rate limiting**: Use a private RPC endpoint
3. **Archive state issues**: Use a specific recent block number
4. **No whales found**: Check the addresses on BaseScan manually

