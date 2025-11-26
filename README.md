# MorphoV1Vaults - Multi-Asset Yield Optimization System

A comprehensive vault system for managing multi-asset yield optimization on Base network, integrating with Morpho vaults, Aerodrome DEX, and Merkl rewards. Built for the **SurfLiquid.com** platform.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Installation](#installation)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Testing](#testing)
- [Usage](#usage)
- [Security Considerations](#security-considerations)
- [Contract Addresses](#contract-addresses)
- [License](#license)

## Overview

The MorphoV1Vaults system consists of two main contracts:

1. **UserVaultFactory** - Deploys deterministic user vaults using CREATE2 for cross-chain address consistency
2. **UserVault_V4** - Multi-asset yield optimization vault with fee management, rebalancing, and Merkl reward claiming

### Key Capabilities

- 📊 **Multi-Asset Support**: Manage USDC, WETH, cbBTC, and other assets in a single vault
- 🔄 **Automated Rebalancing**: Move funds between Morpho vaults to optimize yields
- 💰 **Fee Management**: Configurable fees for withdrawals, rebalancing, and Merkl claims
- 🎁 **Merkl Integration**: Automated reward claiming with fee distribution
- 🔀 **Token Swapping**: Integrated Aerodrome DEX for optimal token swaps
- 🛡️ **Security**: Built with OpenZeppelin contracts, reentrancy guards, and pausability

## Features

### UserVaultFactory

- ✅ **Deterministic Deployment**: CREATE2 for predictable cross-chain addresses
- ✅ **Vault Registry**: Track all deployed vaults by owner
- ✅ **Deployment Fees**: Optional fees for vault creation
- ✅ **Cross-Chain Registry**: Register vaults deployed on other chains
- ✅ **Emergency Controls**: Pause/unpause deployment functionality

### UserVault_V4

- ✅ **Multi-Asset Management**: Support unlimited assets with individual vaults
- ✅ **Morpho Integration**: Deposit/withdraw via Morpho Bundler for gas efficiency
- ✅ **Profit Tracking**: Per-asset profit/loss tracking with rebalance base amounts
- ✅ **Flexible Fee Structure**:
  - Withdrawal fees (only on profit)
  - Rebalance fees (only on profit)
  - Merkl claim fees
  - Minimum profit thresholds
- ✅ **Admin Controls**: Asset management, vault whitelisting, fee configuration
- ✅ **Owner Controls**: Deposits, withdrawals, Merkl claims
- ✅ **View Functions**: Comprehensive portfolio analytics

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   UserVaultFactory                           │
│  - CREATE2 vault deployment                                  │
│  - Vault registry & tracking                                 │
│  - Fee collection                                            │
└──────────────────────┬──────────────────────────────────────┘
                       │ deploys
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    UserVault_V4                              │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │    USDC     │  │     WETH     │  │    cbBTC     │       │
│  │   Tracking  │  │   Tracking   │  │   Tracking   │       │
│  └──────┬──────┘  └──────┬───────┘  └──────┬───────┘       │
│         │                 │                  │               │
│         ▼                 ▼                  ▼               │
│  ┌─────────────────────────────────────────────────┐       │
│  │           Morpho Bundler Integration            │       │
│  └──────────────────┬──────────────────────────────┘       │
└────────────────────┼───────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
        ▼            ▼            ▼
  ┌─────────┐  ┌─────────┐  ┌──────────┐
  │ Morpho  │  │Aerodrome│  │  Merkl   │
  │  Vaults │  │   DEX   │  │Distributor│
  └─────────┘  └─────────┘  └──────────┘
```

## Installation

### Prerequisites

- Node.js >= 18.0.0
- npm or yarn
- Git

### Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/MorphoV1Vaults.git
cd MorphoV1Vaults

# Install dependencies
npm install

# Copy environment file
cp .env.example .env

# Edit .env with your configuration
nano .env
```

## Configuration

### Environment Variables

Create a `.env` file with the following variables:

```bash
# Private Key (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# RPC URLs
BASE_RPC_URL=https://mainnet.base.org
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# API Keys
BASESCAN_API_KEY=your_basescan_api_key_here
COINMARKETCAP_API_KEY=your_coinmarketcap_api_key_here

# Configuration
FORKING=false
REPORT_GAS=true

# Deployment Configuration
DEPLOYMENT_FEE=0  # in wei
FEE_RECIPIENT=your_fee_recipient_address_here

# Vault Configuration
REVENUE_ADDRESS=your_revenue_address_here
FEE_PERCENTAGE=100  # 1% in basis points
REBALANCE_FEE_PERCENTAGE=1000  # 10% in basis points
MERKL_CLAIM_FEE_PERCENTAGE=1000  # 10% in basis points

# Token Addresses (Base Mainnet)
USDC_ADDRESS=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
WETH_ADDRESS=0x4200000000000000000000000000000000000006
CBBTC_ADDRESS=0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf

# Morpho Vault Addresses (Update with actual addresses)
MORPHO_USDC_VAULT=0x0000000000000000000000000000000000000000
MORPHO_WETH_VAULT=0x0000000000000000000000000000000000000000
MORPHO_CBBTC_VAULT=0x0000000000000000000000000000000000000000
```

### Compiler Settings

The contracts use aggressive optimization to minimize size. If you encounter contract size issues:

1. The `hardhat.config.js` uses `runs: 1` for testing
2. For production, adjust `runs` value based on deployment needs
3. Enable `viaIR` for better optimization
4. Consider splitting large contracts into libraries

## Deployment

### Compile Contracts

```bash
npm run compile
```

### Deploy Factory

```bash
# Deploy to localhost
npm run deploy:localhost

# Deploy to Base mainnet
npm run deploy:base

# Deploy to Base Sepolia testnet
npx hardhat run scripts/deploy/deploy.js --network base-sepolia
```

### Deploy Test Vault

```bash
# After deploying factory, deploy a test vault
npx hardhat run scripts/deploy/deployTestVault.js --network localhost <FACTORY_ADDRESS>
```

## Testing

### Run All Tests

```bash
npm test
```

### Run Specific Test Suites

```bash
# Factory tests
npx hardhat test test/unit/UserVaultFactory.test.js

# Vault tests
npx hardhat test test/unit/UserVaultV4.test.js
```

### Run CLI Test Scripts

```bash
# Test all factory functions
npm run cli:factory

# Test all vault functions (documentation mode)
npm run cli:vault
```

### Coverage

```bash
npm run coverage
```

### Gas Reporter

```bash
REPORT_GAS=true npm test
```

### Integration Testing with Forking

To test with real Morpho vaults and tokens:

```bash
# In .env
FORKING=true
BASE_RPC_URL=https://mainnet.base.org

# Run tests
npm test
```

## Usage

### For Users

#### 1. Deploy Your Vault

```javascript
const factory = await ethers.getContractAt("UserVaultFactory", FACTORY_ADDRESS);

const tx = await factory.deployVaultWithNonce(
  ownerAddress,
  adminAddress,
  [USDC_ADDRESS, WETH_ADDRESS],  // assets
  [MORPHO_USDC_VAULT, MORPHO_WETH_VAULT],  // asset vaults
  [MORPHO_USDC_VAULT, MORPHO_WETH_VAULT, MORPHO_CBBTC_VAULT],  // allowed vaults
  revenueAddress,
  100,   // 1% withdrawal fee
  1000,  // 10% rebalance fee
  1000,  // 10% merkl claim fee
  1,     // nonce
  { value: deploymentFee }
);

const receipt = await tx.wait();
const vaultAddress = receipt.logs[0].args[0];
```

#### 2. Make Initial Deposit

```javascript
const vault = await ethers.getContractAt("UserVault_V4", vaultAddress);
const usdc = await ethers.getContractAt("IERC20", USDC_ADDRESS);

// Approve USDC
await usdc.approve(vaultAddress, amount);

// Make initial deposit
await vault.initialDeposit(USDC_ADDRESS, amount);
```

#### 3. Check Portfolio

```javascript
const [assets, deposited, currentValues, profits] = await vault.getPortfolioSummary();

console.log("Assets:", assets);
console.log("Deposited:", deposited);
console.log("Current Values:", currentValues);
console.log("Profits:", profits);
```

#### 4. Withdraw Funds

```javascript
// Withdraw specific amount (in shares)
await vault.withdraw(USDC_ADDRESS, shareAmount);

// Withdraw all (pass 0)
await vault.withdraw(USDC_ADDRESS, 0);
```

### For Admins

#### 1. Rebalance to Better Vault

```javascript
await vault.connect(admin).rebalanceToVault(USDC_ADDRESS, NEW_MORPHO_VAULT);
```

#### 2. Add New Asset

```javascript
await vault.connect(admin).addVault(NEW_VAULT_ADDRESS);
await vault.connect(admin).addAsset(NEW_ASSET_ADDRESS, NEW_VAULT_ADDRESS);
```

#### 3. Update Fees

```javascript
await vault.connect(admin).updateFeePercentage(200);  // 2%
await vault.connect(admin).updateRebalanceFeePercentage(500);  // 5%
```

#### 4. Claim Merkl Rewards

```javascript
// Single claim
await vault.claimMerklReward(tokenAddress, claimableAmount, proof);

// Batch claim
await vault.claimMerklRewardsBatch(
  [token1, token2],
  [amount1, amount2],
  [proof1, proof2]
);
```

## Security Considerations

### Contract Size Warning

⚠️ **Important**: The UserVault_V4 contract exceeds the 24KB size limit (Spurious Dragon). This means:

- ✅ Works on test networks
- ✅ Works with `allowUnlimitedContractSize` flag
- ❌ May not deploy on some mainnet chains
- 💡 Consider refactoring into libraries or proxy patterns for production

### Best Practices

1. **Test Thoroughly**: Always test on testnet before mainnet deployment
2. **Verify Contracts**: Verify on Basescan after deployment
3. **Audit**: Consider professional audits for production use
4. **Gradual Rollout**: Start with small amounts
5. **Monitor**: Set up monitoring for vault activities
6. **Access Control**: Carefully manage admin and owner keys
7. **Pause Functionality**: Use pause in emergencies

### Known Limitations

- Contract size exceeds 24KB limit
- Requires actual Morpho vault addresses
- Gas costs can be high for complex operations
- Rebalancing requires admin action (not automated)

## Contract Addresses

### Base Mainnet (Chain ID: 8453)

#### Protocol Addresses

- **Aerodrome Router**: `0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43`
- **Aerodrome Factory**: `0x420DD381b31aEf6683db6B902084cB0FFECe40Da`
- **Morpho Bundler**: `0x6BFd8137e702540E7A42B74178A4a49Ba43920C4`
- **Morpho Adapter**: `0xb98c948CFA24072e58935BC004a8A7b376AE746A`
- **Merkl Distributor**: `0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae`

#### Token Addresses

- **USDC**: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- **WETH**: `0x4200000000000000000000000000000000000006`
- **cbBTC**: `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf`

#### Deployed Contracts

- **UserVaultFactory**: TBD (Deploy using scripts)
- **Sample UserVault**: TBD (Deploy via factory)

## Documentation

For detailed technical documentation, see:

- [TECHNICAL_DOCS.md](./docs/TECHNICAL_DOCS.md) - Complete function reference
- [scripts/cli/testFactory.js](./scripts/cli/testFactory.js) - Factory function examples
- [scripts/cli/testVault.js](./scripts/cli/testVault.js) - Vault function examples

## Project Structure

```
MorphoV1Vaults/
├── contracts/
│   ├── UserVaultFactory.sol      # Factory contract
│   ├── userVaultV4.sol            # Main vault contract
│   └── Interfaces/                # Interface definitions
│       ├── IAerodrome.sol
│       ├── IMetaMorpho.sol
│       ├── IBundler.sol
│       ├── IERC20Extended.sol
│       └── IMerklDistributor.sol
├── scripts/
│   ├── deploy/
│   │   ├── deploy.js              # Deploy factory
│   │   └── deployTestVault.js     # Deploy test vault
│   └── cli/
│       ├── testFactory.js         # CLI tests for factory
│       └── testVault.js           # CLI tests for vault
├── test/
│   └── unit/
│       ├── UserVaultFactory.test.js
│       └── UserVaultV4.test.js
├── hardhat.config.js
├── package.json
└── README.md
```

## Development

### Add New Features

1. Create feature branch: `git checkout -b feature/new-feature`
2. Make changes and add tests
3. Run tests: `npm test`
4. Submit pull request

### Code Style

- Follow Solidity style guide
- Use NatSpec comments
- Add comprehensive tests
- Update documentation

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## Support

For issues and questions:

- GitHub Issues: [https://github.com/yourusername/MorphoV1Vaults/issues](https://github.com/yourusername/MorphoV1Vaults/issues)
- Documentation: [./docs/](./docs/)
- CLI Tests: Run `npm run cli:factory` or `npm run cli:vault`

## License

MIT License - see [LICENSE](./LICENSE) file for details

---

**⚠️ Disclaimer**: This software is provided as-is. Users should conduct their own audits and testing before using in production. The developers assume no liability for any losses incurred through the use of this software.

Built with ❤️ for the SurfLiquid.com platform
