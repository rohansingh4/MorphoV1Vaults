# Remix IDE Setup with Hardhat Forked Base Network

This guide shows how to connect Remix IDE to a Hardhat forked Base mainnet node.

## 🚀 Quick Start

### Method 1: Using npm scripts (Recommended)

**Terminal 1 - Start Forked Node:**
```bash
npm run node:fork
```

**Terminal 2 - Seed USDC (after node starts):**
```bash
npm run fork:setup
```

### Method 2: Using shell script

```bash
./scripts/fork/startForkedNode.sh
```

Then in another terminal:
```bash
npm run fork:setup
```

### Method 3: Manual commands

**Terminal 1:**
```bash
FORKING=true npx hardhat node
```

**Terminal 2:**
```bash
FORKING=true npx hardhat run scripts/fork/setupForkNode.js
```

## 📡 Connect Remix IDE

1. **Open Remix IDE**: https://remix.ethereum.org

2. **Navigate to Deploy Tab**:
   - Click on "Deploy & Run Transactions" in the left sidebar

3. **Select Environment**:
   - Under "Environment", select **"External Http Provider"**
   - A dialog will appear asking for the RPC URL

4. **Enter Node URL**:
   - URL: `http://127.0.0.1:8545`
   - Click **"OK"** or **"Connect"**

5. **Verify Connection**:
   - You should see your Hardhat accounts in the "Account" dropdown
   - Each account has 10,000 ETH and 10,000 USDC (after running setup)

## 💰 Account Information

### Default Hardhat Accounts

After running `npm run fork:setup`, these accounts have:

- **10,000 ETH** (default Hardhat accounts)
- **10,000 USDC** (seeded from Base system contract)

| Account # | Address | Private Key |
|-----------|---------|-------------|
| 0 | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` |
| 1 | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d` |
| 2 | `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC` | `0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a` |

**⚠️ WARNING**: These accounts and private keys are publicly known. Only use them in test environments!

## 🧪 Testing Contracts

### In Remix IDE:

1. **Compile your contract** in Remix
2. **Select contract** in the Deploy tab
3. **Choose an account** with USDC from dropdown
4. **Deploy** - transactions will execute on the forked Base network
5. **Interact** with deployed contracts using Base mainnet addresses

### Example: Interact with USDC

The USDC contract on Base is at:
```
0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
```

In Remix:
1. At Address: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
2. Load contract using USDC ABI
3. Call `balanceOf` with your account address to see USDC balance

## 🔧 Configuration

### Custom RPC Endpoint

If you want to use a different RPC endpoint:

```bash
FORKING=true BASE_RPC_URL=https://base-mainnet.g.alchemy.com/v2/YOUR_KEY npx hardhat node
```

### Fork at Specific Block

```bash
FORKING=true FORK_BLOCK_NUMBER=12345678 npx hardhat node
```

## 🐛 Troubleshooting

### Node won't start
- **Port 8545 in use**: Kill the process using port 8545
  ```bash
  lsof -ti:8545 | xargs kill -9
  ```

### Remix can't connect
- **Check node is running**: You should see "Started HTTP and WebSocket JSON-RPC server"
- **Check URL**: Use `http://127.0.0.1:8545` (not `localhost`)
- **Firewall**: Ensure localhost connections are allowed
- **Browser**: Try refreshing Remix or using incognito mode

### No USDC in accounts
- Run the setup script: `npm run fork:setup`
- Check the node is forking Base (not regular Hardhat network)
- Verify USDC contract exists at `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`

### Fork connection errors
- Ensure `FORKING=true` is set when starting node
- Check your RPC endpoint is accessible
- Try using a different RPC provider (Alchemy, Infura, etc.)

## 📝 Notes

- The forked node maintains Base mainnet state as of the fork block
- All transactions execute locally (no gas costs on real network)
- You can impersonate any account on Base using Hardhat helpers
- The node continues running until you stop it (Ctrl+C)

## 🔗 Useful Links

- Base Mainnet Explorer: https://basescan.org
- USDC on Base: https://basescan.org/token/0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
- Remix IDE: https://remix.ethereum.org
- Hardhat Docs: https://hardhat.org/docs


