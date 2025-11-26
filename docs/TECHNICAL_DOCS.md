# Technical Documentation - MorphoV1Vaults

Complete technical reference for all functions in the MorphoV1Vaults system.

## Table of Contents

1. [UserVaultFactory](#uservaultfactory)
   - [Constructor](#factory-constructor)
   - [Deployment Functions](#deployment-functions)
   - [View Functions](#factory-view-functions)
   - [Admin Functions](#factory-admin-functions)
   - [Emergency Functions](#factory-emergency-functions)

2. [UserVault_V4](#uservault_v4)
   - [Constructor](#vault-constructor)
   - [Admin Functions](#vault-admin-functions)
   - [Deposit Functions](#deposit-functions)
   - [Withdrawal Functions](#withdrawal-functions)
   - [Rebalance Functions](#rebalance-functions)
   - [Merkl Functions](#merkl-functions)
   - [View Functions](#vault-view-functions)
   - [Internal Functions](#internal-functions)

---

# UserVaultFactory

Factory contract for deterministic cross-chain deployment of UserVault_V4 contracts using CREATE2.

## Factory Constructor

### `constructor(address _initialOwner, uint256 _deploymentFee, address _feeRecipient)`

Initializes the factory with ownership and fee configuration.

**Parameters:**
- `_initialOwner` (address): Address that will own the factory contract
- `_deploymentFee` (uint256): Fee in wei required to deploy a vault
- `_feeRecipient` (address): Address to receive deployment fees (uses owner if zero address)

**Access:** Public (called during deployment)

**Example:**
```solidity
UserVaultFactory factory = new UserVaultFactory(
    msg.sender,              // owner
    0.001 ether,             // deployment fee
    feeRecipientAddress      // fee recipient
);
```

---

## Deployment Functions

### `deployVault(...)`

```solidity
function deployVault(
    address owner,
    address admin,
    address[] memory assets,
    address[] memory assetVaults,
    address[] memory initialAllowedVaults,
    address revenueAddress,
    uint256 feePercentage,
    uint256 rebalanceFeePercentage,
    uint256 merklClaimFeePercentage,
    bytes32 salt
) external payable nonReentrant whenNotPaused returns (address vaultAddress)
```

Deploys a new UserVault_V4 contract with deterministic address using CREATE2.

**Parameters:**
- `owner`: The owner of the vault (user)
- `admin`: The admin who manages the vault
- `assets`: Array of initial assets (e.g., USDC, WETH, cbBTC)
- `assetVaults`: Array of initial vaults for each asset (must match assets length)
- `initialAllowedVaults`: Array of all vaults that are whitelisted
- `revenueAddress`: Address to receive fees
- `feePercentage`: Withdrawal fee percentage in basis points (100 = 1%)
- `rebalanceFeePercentage`: Rebalance fee percentage in basis points (1000 = 10%)
- `merklClaimFeePercentage`: Merkl claim fee percentage in basis points (1000 = 10%)
- `salt`: Unique salt for deterministic deployment

**Returns:**
- `vaultAddress`: The deployed vault address

**Modifiers:**
- `nonReentrant`: Prevents reentrancy attacks
- `whenNotPaused`: Only works when factory is not paused

**Requirements:**
- Deployment fee must be paid (msg.value >= deploymentFee)
- Salt not already used by this owner
- Owner and admin must be valid addresses
- Assets array must not be empty
- Assets and assetVaults arrays must have same length
- All allowed vaults must be provided
- Revenue address must be valid
- All asset and vault addresses must be non-zero

**Events Emitted:**
- `VaultDeployed(vaultAddress, owner, admin, salt, chainId)`

**Example:**
```solidity
address vault = factory.deployVault{value: 0.001 ether}(
    userAddress,
    adminAddress,
    [USDC, WETH],
    [morphoUSDCVault, morphoWETHVault],
    [morphoUSDCVault, morphoWETHVault, morphoCBBTCVault],
    revenueAddress,
    100,   // 1%
    1000,  // 10%
    1000,  // 10%
    salt
);
```

---

### `deployVaultWithNonce(...)`

```solidity
function deployVaultWithNonce(
    address owner,
    address admin,
    address[] memory assets,
    address[] memory assetVaults,
    address[] memory initialAllowedVaults,
    address revenueAddress,
    uint256 feePercentage,
    uint256 rebalanceFeePercentage,
    uint256 merklClaimFeePercentage,
    uint256 nonce
) external payable returns (address vaultAddress, bytes32 salt)
```

Convenience function that generates salt from owner and nonce, then deploys vault.

**Parameters:**
- Same as `deployVault` except `nonce` instead of `salt`
- `nonce`: Unique number for the owner (allows multiple vaults per owner)

**Returns:**
- `vaultAddress`: The deployed vault address
- `salt`: The generated salt used for deployment

**Example:**
```solidity
(address vault, bytes32 salt) = factory.deployVaultWithNonce{value: 0.001 ether}(
    userAddress,
    adminAddress,
    [USDC, WETH],
    [morphoUSDCVault, morphoWETHVault],
    [morphoUSDCVault, morphoWETHVault],
    revenueAddress,
    100, 1000, 1000,
    1  // nonce
);
```

---

### `computeVaultAddress(...)`

```solidity
function computeVaultAddress(
    address owner,
    address admin,
    address[] memory assets,
    address[] memory assetVaults,
    address[] memory initialAllowedVaults,
    address revenueAddress,
    uint256 feePercentage,
    uint256 rebalanceFeePercentage,
    uint256 merklClaimFeePercentage,
    bytes32 salt
) public view returns (address predictedAddress)
```

Computes the address where a vault would be deployed with given parameters.

**Purpose:** Allows predicting vault address before deployment for cross-chain coordination.

**Returns:**
- `predictedAddress`: The address where the vault will be deployed

**Example:**
```solidity
address predicted = factory.computeVaultAddress(
    owner, admin, assets, assetVaults,
    initialAllowedVaults, revenueAddress,
    100, 1000, 1000, salt
);
// Deploy to this exact address on multiple chains
```

---

### `generateDeterministicSalt(address owner, uint256 nonce)`

```solidity
function generateDeterministicSalt(address owner, uint256 nonce)
    public pure returns (bytes32)
```

Generates a deterministic salt based on owner and nonce.

**Parameters:**
- `owner`: The vault owner address
- `nonce`: A unique nonce for the owner

**Returns:**
- `bytes32`: Generated salt (keccak256 hash of owner + nonce)

**Purpose:** Ensures same salt across different chains for same user and nonce.

**Example:**
```solidity
bytes32 salt = factory.generateDeterministicSalt(msg.sender, 1);
// Same salt will be generated on all chains
```

---

## Factory View Functions

### `getTotalVaults()`

```solidity
function getTotalVaults() external view returns (uint256)
```

Returns total number of vaults in the registry.

**Returns:** Total vault count including cross-chain registered vaults

---

### `getOwnerVaults(address owner)`

```solidity
function getOwnerVaults(address owner) external view returns (address[] memory)
```

Returns all vaults deployed by a specific owner on this chain.

**Parameters:**
- `owner`: Address to query

**Returns:** Array of vault addresses

---

### `getVaultIndicesByOwner(address owner)`

```solidity
function getVaultIndicesByOwner(address owner)
    external view returns (uint256[] memory)
```

Returns registry indices for all vaults owned by an address.

**Returns:** Array of indices in the vaultRegistry

---

### `getVaultInfo(uint256 index)`

```solidity
function getVaultInfo(uint256 index) external view returns (VaultInfo memory)
```

Returns detailed information about a vault by registry index.

**Returns:** VaultInfo struct containing:
- `vaultAddress`: Vault contract address
- `owner`: Vault owner
- `admin`: Vault admin
- `chainId`: Chain where vault is deployed
- `salt`: Salt used for deployment
- `deployedAt`: Timestamp of deployment

---

### `isVaultFromFactory(address vault)`

```solidity
function isVaultFromFactory(address vault) external view returns (bool)
```

Checks if a vault was deployed by this factory.

**Returns:** `true` if vault is from this factory

---

## Factory Admin Functions

### `setDeploymentFee(uint256 newFee)`

```solidity
function setDeploymentFee(uint256 newFee) external onlyOwner
```

Updates the deployment fee.

**Access:** Owner only

**Parameters:**
- `newFee`: New fee in wei

---

### `setFeeRecipient(address newRecipient)`

```solidity
function setFeeRecipient(address newRecipient) external onlyOwner
```

Updates the fee recipient address.

**Access:** Owner only

**Requirements:**
- `newRecipient` must not be zero address

---

### `pause()` / `unpause()`

```solidity
function pause() external onlyOwner
function unpause() external onlyOwner
```

Emergency pause/unpause of vault deployments.

**Access:** Owner only

---

### `registerCrossChainVault(...)`

```solidity
function registerCrossChainVault(
    address vaultAddress,
    address owner,
    address admin,
    uint256 chainId,
    bytes32 salt
) external onlyOwner
```

Registers a vault deployed on another chain for tracking purposes.

**Access:** Owner only

**Requirements:**
- `chainId` must be different from current chain
- `vaultAddress`, `owner` must be valid

**Events Emitted:**
- `VaultRegistered(vaultAddress, owner, chainId)`

---

## Factory Emergency Functions

### `emergencyWithdraw()`

```solidity
function emergencyWithdraw() external onlyOwner
```

Withdraws all ETH from the factory contract.

**Access:** Owner only

**Requirements:**
- Contract must have ETH balance

---

# UserVault_V4

Multi-asset individual user vault contract for yield optimization.

## Vault Constructor

### `constructor(...)`

```solidity
constructor(
    address _owner,
    address _admin,
    address[] memory _assets,
    address[] memory _assetVaults,
    address[] memory _initialAllowedVaults,
    address _revenueAddress,
    uint256 _feePercentage,
    uint256 _rebalanceFeePercentage,
    uint256 _merklClaimFeePercentage
)
```

Initializes a multi-asset vault.

**Parameters:**
- `_owner`: The owner of the vault (user who deposits/withdraws)
- `_admin`: The admin who manages the vault (rebalancing, config)
- `_assets`: Array of initial assets to support (e.g., [USDC, WETH])
- `_assetVaults`: Array of initial Morpho vaults for each asset
- `_initialAllowedVaults`: Array of all vaults that are whitelisted
- `_revenueAddress`: Address to receive fees
- `_feePercentage`: Withdrawal fee in basis points (100 = 1%)
- `_rebalanceFeePercentage`: Rebalance fee in basis points (1000 = 10%)
- `_merklClaimFeePercentage`: Merkl claim fee in basis points (1000 = 10%)

**Requirements:**
- All addresses must be valid (non-zero)
- At least one asset must be provided
- Assets and assetVaults arrays must match in length
- No duplicate assets allowed

**Initializes:**
- Asset-to-vault mappings
- Allowed assets and vaults
- Fee configuration
- Owner and admin roles

---

## Vault Admin Functions

### `addAsset(address asset, address vault)`

```solidity
function addAsset(address asset, address vault) external onlyAdmin
```

Adds a new asset with its corresponding Morpho vault.

**Access:** Admin only

**Parameters:**
- `asset`: Token address (e.g., USDC, WETH)
- `vault`: Morpho vault address for this asset

**Requirements:**
- Asset and vault must be non-zero addresses
- Asset must not already exist
- Vault must be in whitelist
- Vault's underlying asset must match provided asset

**Events Emitted:**
- `AssetAdded(asset, vault)`

**Example:**
```solidity
vault.addAsset(cbBTCAddress, morphoCBBTCVault);
```

---

### `removeAsset(address asset)`

```solidity
function removeAsset(address asset) external onlyAdmin
```

Removes an asset from the vault.

**Access:** Admin only

**Requirements:**
- Asset must be allowed
- Asset must have no deposits (initial deposit not made)

**Events Emitted:**
- `AssetRemoved(asset)`

---

### `updateAssetVault(address asset, address newVault)`

```solidity
function updateAssetVault(address asset, address newVault)
    external onlyAdmin onlyAllowedAsset(asset) onlyAllowedVault(newVault)
```

Updates the Morpho vault for a specific asset.

**Access:** Admin only

**Parameters:**
- `asset`: Asset to update
- `newVault`: New Morpho vault address

**Requirements:**
- Asset must be allowed
- New vault must be in whitelist
- New vault's asset must match
- New vault must be different from current vault

**Events Emitted:**
- `AssetVaultUpdated(asset, oldVault, newVault)`

**Note:** Does not move funds. Use `rebalanceToVault()` to move funds.

---

### `addVault(address vault)`

```solidity
function addVault(address vault) external onlyAdmin
```

Adds a new Morpho vault to the whitelist.

**Access:** Admin only

**Requirements:**
- Vault must be valid address
- Vault not already in whitelist

**Events Emitted:**
- `VaultAdded(vault)`

---

### `removeVault(address vault)`

```solidity
function removeVault(address vault) external onlyAdmin
```

Removes a Morpho vault from the whitelist.

**Access:** Admin only

**Requirements:**
- Vault must be in whitelist
- No asset can be currently using this vault

**Events Emitted:**
- `VaultRemoved(vault)`

---

### `updateRevenueAddress(address newRevenueAddress)`

```solidity
function updateRevenueAddress(address newRevenueAddress) external onlyAdmin
```

Updates the address that receives fees.

**Access:** Admin only

**Requirements:**
- Address must be valid (non-zero)

**Events Emitted:**
- `RevenueAddressUpdated(oldAddress, newAddress)`

---

### `updateFeePercentage(uint256 newFeePercentage)`

```solidity
function updateFeePercentage(uint256 newFeePercentage) external onlyAdmin
```

Updates the withdrawal fee percentage.

**Access:** Admin only

**Parameters:**
- `newFeePercentage`: New fee in basis points (100 = 1%)

**Events Emitted:**
- `FeePercentageUpdated(oldFee, newFee)`

**Example:**
```solidity
vault.updateFeePercentage(200);  // Set to 2%
```

---

### `updateRebalanceFeePercentage(uint256 newRebalanceFeePercentage)`

```solidity
function updateRebalanceFeePercentage(uint256 newRebalanceFeePercentage)
    external onlyAdmin
```

Updates the rebalance fee percentage (charged on profit during rebalancing).

**Access:** Admin only

**Parameters:**
- `newRebalanceFeePercentage`: New fee in basis points

**Events Emitted:**
- `RebalanceFeePercentageUpdated(oldFee, newFee)`

---

### `updateMerklClaimFeePercentage(uint256 newMerklClaimFeePercentage)`

```solidity
function updateMerklClaimFeePercentage(uint256 newMerklClaimFeePercentage)
    external onlyAdmin
```

Updates the Merkl claim fee percentage.

**Access:** Admin only

**Events Emitted:**
- `MerklClaimFeePercentageUpdated(oldFee, newFee)`

---

### `updateMinProfitForFee(uint256 newMinProfitForFee)`

```solidity
function updateMinProfitForFee(uint256 newMinProfitForFee) external onlyAdmin
```

Updates minimum profit threshold for charging fees.

**Access:** Admin only

**Default:** 10e6 ($10 in USDC with 6 decimals)

**Purpose:** Small profits don't trigger fees, reducing gas costs for users.

**Requirements:**
- Must be greater than zero

**Events Emitted:**
- `MinProfitForFeeUpdated(oldThreshold, newThreshold)`

---

### `updateAdmin(address newAdmin)`

```solidity
function updateAdmin(address newAdmin) external onlyAdmin
```

Transfers admin rights to a new address.

**Access:** Admin only

**Requirements:**
- New admin must be valid address

**Events Emitted:**
- `AdminUpdated(oldAdmin, newAdmin)`

---

### `pause()` / `unpause()`

```solidity
function pause() external onlyAdmin
function unpause() external onlyAdmin
```

Emergency pause/unpause of vault operations.

**Access:** Admin only

**Effects:**
- When paused: deposits, withdrawals, rebalancing blocked
- When paused: only emergency withdraw allowed

---

## Deposit Functions

### `initialDeposit(address asset, uint256 amount)`

```solidity
function initialDeposit(address asset, uint256 amount)
    external onlyOwner onlyAllowedAsset(asset) nonReentrant whenNotPaused
```

Makes the first deposit for a specific asset.

**Access:** Owner only

**Parameters:**
- `asset`: Asset to deposit (e.g., USDC)
- `amount`: Amount to deposit

**Requirements:**
- Asset must be allowed
- Initial deposit not yet made for this asset
- Amount must be greater than zero
- Owner must have approved vault to spend tokens

**Process:**
1. Approves admin as Merkl operator (first deposit only)
2. Transfers asset from owner to vault
3. Deposits to Morpho vault via bundler
4. Sets initial deposit flag
5. Initializes profit tracking (assetRebalanceBaseAmount)

**Events Emitted:**
- `MerklOperatorApproved(admin)` (first time only)
- `InitialDeposit(asset, vault, amount)`

**Example:**
```solidity
// Approve first
usdc.approve(vaultAddress, 1000e6);
// Then deposit
vault.initialDeposit(usdcAddress, 1000e6);
```

---

### `userDeposit(address asset, uint256 amount)`

```solidity
function userDeposit(address asset, uint256 amount)
    external onlyOwner onlyAllowedAsset(asset) nonReentrant whenNotPaused
```

Additional deposits by owner after initial deposit.

**Access:** Owner only

**Requirements:**
- Initial deposit must already be made
- Amount must be greater than zero

**Process:**
1. Transfers asset from owner to vault
2. Deposits to Morpho vault
3. Updates tracking (totalDeposited, rebalanceBaseAmount, lastDepositTime)

**Events Emitted:**
- `UserDeposit(asset, vault, amount)`

---

### `adminDeposit(address asset, uint256 amount)`

```solidity
function adminDeposit(address asset, uint256 amount)
    external onlyAdmin onlyAllowedAsset(asset) nonReentrant whenNotPaused
```

Allows admin to deposit on behalf of user.

**Access:** Admin only

**Behavior:** Same as `userDeposit` but transfers from admin's address

**Use Case:** Automated deposits by admin bot

---

## Withdrawal Functions

### `withdraw(address asset, uint256 amount)`

```solidity
function withdraw(address asset, uint256 amount)
    external onlyOwner onlyAllowedAsset(asset) nonReentrant whenNotPaused
```

Withdraws assets from the vault.

**Access:** Owner only

**Parameters:**
- `asset`: Asset to withdraw
- `amount`: Amount of shares to withdraw (0 = full withdrawal)

**Process:**
1. Redeems shares from Morpho vault
2. Calculates profit-based fee
3. Transfers fee to revenue address (if profitable)
4. Transfers remaining amount to owner
5. Updates assetTotalDeposited

**Fee Calculation:**
- Only charges fee if there's profit
- Only on profit portion, not principal
- Only if profit exceeds minProfitForFee threshold

**Events Emitted:**
- `FeeCollected(asset, vault, feeAmount, userAmount)` (if fee charged)
- `Withdrawal(asset, vault, owner, userAmount)`

**Example:**
```solidity
// Withdraw half
vault.withdraw(usdcAddress, shares / 2);

// Withdraw all
vault.withdraw(usdcAddress, 0);
```

---

### `emergencyWithdraw(address asset)`

```solidity
function emergencyWithdraw(address asset)
    external onlyOwner onlyAllowedAsset(asset) whenPaused nonReentrant
```

Emergency withdrawal when contract is paused.

**Access:** Owner only

**Requirements:**
- Contract must be paused

**Behavior:** Withdraws all shares for the asset, applies standard fee calculation

---

### `emergencyTokenWithdraw(address token, uint256 amount)`

```solidity
function emergencyTokenWithdraw(address token, uint256 amount)
    external onlyOwner nonReentrant
```

Withdraws any ERC20 tokens stuck in the contract.

**Access:** Owner only

**Parameters:**
- `token`: Token address
- `amount`: Amount to withdraw (0 = all)

**Use Case:** Recover accidentally sent tokens or reward tokens

---

## Rebalance Functions

### `rebalanceToVault(address asset, address toVault)`

```solidity
function rebalanceToVault(address asset, address toVault)
    external onlyAdmin onlyAllowedAsset(asset) onlyAllowedVault(toVault)
    nonReentrant whenNotPaused
```

Moves an asset to a different Morpho vault.

**Access:** Admin only

**Parameters:**
- `asset`: Asset to rebalance
- `toVault`: Target Morpho vault

**Requirements:**
- Asset must be allowed
- Target vault must be in whitelist
- Target vault must support the asset
- Target vault must be different from current vault
- Asset must have deposits

**Process:**
1. Redeems all shares from current vault
2. Calculates profit vs base amount
3. If profitable:
   - Deducts rebalanceFeePercentage from profit
   - Transfers fee to revenue address
4. Deposits remaining amount to new vault
5. Updates assetRebalanceBaseAmount
6. Updates assetToVault mapping

**Events Emitted:**
- `RebalanceFeeCollected(asset, profit, fee, newBaseAmount)` (if profitable)
- `Rebalanced(asset, fromVault, toVault, amount)`

**Example:**
```solidity
// Move USDC to better vault
vault.rebalanceToVault(usdcAddress, higherYieldVault);
```

**Profit Tracking:**
- `assetRebalanceBaseAmount`: Tracks the base amount for profit calculation
- Profit = Current Value - Base Amount
- Fee only charged on profit
- Base amount updated after each rebalance

---

## Merkl Functions

### `claimMerklReward(address token, uint256 claimable, bytes32[] proof)`

```solidity
function claimMerklReward(
    address token,
    uint256 claimable,
    bytes32[] calldata proof
) external onlyOwner nonReentrant
```

Claims a single Merkl reward token.

**Access:** Owner only

**Parameters:**
- `token`: Reward token address
- `claimable`: Amount to claim (from Merkl proof)
- `proof`: Merkle proof for claiming

**Process:**
1. Claims rewards from Merkl distributor
2. Deducts merklClaimFeePercentage
3. Transfers fee to revenue address
4. Transfers remaining to owner

**Events Emitted:**
- `MerklTokensClaimed(token, totalAmount, feeAmount, userAmount)`

**Example:**
```solidity
// Get proof from Merkl API
bytes32[] memory proof = getMerklProof(vaultAddress, tokenAddress);
uint256 claimable = getClaimableAmount(vaultAddress, tokenAddress);

vault.claimMerklReward(tokenAddress, claimable, proof);
```

---

### `claimMerklRewardsBatch(...)`

```solidity
function claimMerklRewardsBatch(
    address[] calldata tokens,
    uint256[] calldata claimables,
    bytes32[][] calldata proofs
) external onlyOwner nonReentrant
```

Claims multiple Merkl rewards in one transaction.

**Access:** Owner only

**Requirements:**
- Arrays must have same length
- Arrays must not be empty
- Each token must be valid

**Events Emitted:**
- `MerklTokensClaimed(...)` for each token

---

### `adminClaimMerklReward(...)`

```solidity
function adminClaimMerklReward(
    address token,
    uint256 claimable,
    bytes32[] calldata proof
) external onlyAdmin nonReentrant
```

Admin claims Merkl rewards on behalf of user.

**Access:** Admin only

**Behavior:** Same as `claimMerklReward` but accessible by admin

**Use Case:** Automated reward claiming by admin bot

---

### `adminClaimMerklRewardsBatch(...)`

```solidity
function adminClaimMerklRewardsBatch(
    address[] calldata tokens,
    uint256[] calldata claimables,
    bytes32[][] calldata proofs
) external onlyAdmin nonReentrant
```

Admin batch claims multiple rewards.

**Access:** Admin only

---

### `isAdminApprovedForMerkl()`

```solidity
function isAdminApprovedForMerkl() external view returns (bool)
```

Checks if admin is approved as Merkl operator.

**Returns:** `true` if admin can claim on behalf of vault

**Note:** Automatically set to true on first deposit

---

## Vault View Functions

### Balance Functions

#### `getAssetVaultBalance(address asset)`

Returns vault shares for an asset.

**Returns:** Number of shares held in Morpho vault

---

#### `getAssetVaultAssets(address asset)`

Returns underlying asset value.

**Returns:** Value of shares converted to underlying assets

**Formula:** `shares * (assets per share)`

---

#### `getTokenBalance(address token)`

Returns balance of any token in the contract.

**Returns:** Token balance

**Use Case:** Check reward tokens, accidentally sent tokens

---

### Profit Tracking Functions

#### `getAssetProfit(address asset)`

```solidity
function getAssetProfit(address asset) external view returns (int256)
```

Returns profit or loss for an asset.

**Returns:**
- Positive: Profit amount
- Negative: Loss amount
- Zero: No profit/loss or no deposits

**Formula:** `current value - total deposited`

---

#### `getAssetProfitPercentage(address asset)`

```solidity
function getAssetProfitPercentage(address asset) external view returns (int256)
```

Returns profit percentage with 6 decimal precision.

**Returns:** Profit % * 1,000,000

**Examples:**
- `50000` = 5% profit (50000 / 1000000)
- `-25000` = 2.5% loss

---

### Rebalance Tracking Functions

#### `getAssetRebalanceBaseAmount(address asset)`

Returns the base amount used for rebalance profit calculation.

**Returns:** Base amount in asset's decimals

---

#### `getAssetRebalanceProfit(address asset)`

```solidity
function getAssetRebalanceProfit(address asset)
    external view returns (int256 profit)
```

Returns unrealized rebalance profit.

**Returns:**
- Positive: Unrealized profit since last rebalance
- Negative: Unrealized loss

**Formula:** `current value - rebalance base amount`

---

#### `getAssetTotalRebalanceFees(address asset)`

Returns total rebalance fees collected for an asset.

**Returns:** Total fees in asset's decimals

---

#### `getAssetRebalanceInfo(address asset)`

```solidity
function getAssetRebalanceInfo(address asset)
    external view returns (
        uint256 baseAmount,
        uint256 currentValue,
        int256 profit,
        uint256 totalFees
    )
```

Returns complete rebalance information.

**Returns:**
- `baseAmount`: Base amount for profit calculation
- `currentValue`: Current value in vault
- `profit`: Unrealized profit/loss
- `totalFees`: Total rebalance fees collected

---

### Configuration Functions

#### `getAllowedAssets()`

Returns array of all allowed assets.

---

#### `getAllowedVaults()`

Returns array of all whitelisted Morpho vaults.

---

#### `getFeeInfo()`

```solidity
function getFeeInfo() external view returns (
    address _revenueAddress,
    uint256 _feePercentage,
    uint256 _minProfitForFee
)
```

Returns fee configuration.

---

#### `getAssetFeesCollected(address asset)`

Returns total withdrawal fees collected for an asset.

---

### Portfolio Functions

#### `getPortfolioSummary()`

```solidity
function getPortfolioSummary() external view returns (
    address[] memory assets,
    uint256[] memory deposited,
    uint256[] memory currentValues,
    int256[] memory profits
)
```

Returns complete portfolio overview.

**Returns:**
- `assets`: All assets with deposits
- `deposited`: Total deposited per asset
- `currentValues`: Current value per asset
- `profits`: Profit/loss per asset

**Example:**
```javascript
const [assets, deposited, values, profits] = await vault.getPortfolioSummary();
console.log("USDC deposited:", deposited[0]);
console.log("USDC current value:", values[0]);
console.log("USDC profit:", profits[0]);
```

---

### Fee Calculation Function

#### `calculateFeeFromProfit(address asset, uint256 totalAmount)`

```solidity
function calculateFeeFromProfit(address asset, uint256 totalAmount)
    public view returns (uint256 feeAmount, uint256 userAmount)
```

Calculates fee based on profit.

**Parameters:**
- `asset`: Asset to calculate fees for
- `totalAmount`: Total amount being withdrawn

**Returns:**
- `feeAmount`: Fee to be charged
- `userAmount`: Amount user receives

**Logic:**
1. If no profit or loss: No fee
2. If profit < minProfitForFee: No fee
3. If profitable: Fee = (profit * feePercentage) / 10000

**Example:**
```solidity
// User deposited 1000 USDC
// Current value: 1100 USDC
// Profit: 100 USDC
// feePercentage: 1% (100 basis points)

(uint256 fee, uint256 userAmount) = vault.calculateFeeFromProfit(usdc, 1100e6);
// fee = 1 USDC (1% of 100 profit)
// userAmount = 1099 USDC
```

---

## Internal Functions

### `_depositToVaultViaBundler(address vault, uint256 amount, address vaultAsset)`

Deposits to Morpho vault using the bundler for gas efficiency.

**Process:**
1. Approves adapter to spend tokens
2. Calls bundler.multicall with:
   - erc20TransferFrom: Transfer tokens to adapter
   - erc4626Deposit: Deposit into vault
3. Vault shares credited to this contract

---

### `_redeemFromVaultViaBundler(address vault, uint256 shares)`

Redeems from Morpho vault using the bundler.

**Process:**
1. Approves adapter to spend shares
2. Calls bundler.multicall with:
   - erc20TransferFrom: Transfer shares to adapter
   - erc4626Redeem: Redeem from vault
3. Underlying assets returned to this contract

---

### `_swapTokens(address tokenIn, address tokenOut, uint256 amountIn)`

Swaps tokens using Aerodrome DEX.

**Features:**
- Automatically selects best pool (stable vs volatile)
- 5% slippage tolerance
- Checks both pool types and compares outputs

**Process:**
1. Check if stable and volatile pools exist
2. Determine which pool gives better output
3. Execute swap on selected pool
4. Return amount received

**Events Emitted:**
- `AssetSwapped(tokenIn, tokenOut, amountIn, amountOut)`

---

### `_shouldUseStablePool(...)`

Determines which Aerodrome pool type to use.

**Logic:**
1. If only one pool exists, use it
2. If both exist, compare outputs
3. Add 0.1% bias towards stable pools
4. Return pool with better output

---

### `_getPoolOutput(address tokenIn, address tokenOut, uint256 amountIn, bool stable)`

Gets expected output from a specific Aerodrome pool.

**Returns:** Expected output amount or 0 if pool doesn't exist

---

### `_approveMerklOperator()`

Approves admin as Merkl operator.

**Called:** Automatically on first deposit

**Effect:** Allows admin to claim Merkl rewards on behalf of vault

---

### `_convertToAssetDecimals(uint256 usdcAmount, address asset)`

Converts USDC-based amount (6 decimals) to asset's decimal format.

**Examples:**
- USDC (6 decimals): No conversion
- WETH (18 decimals): Multiply by 10^12
- Custom (8 decimals): Multiply by 10^2

---

### `_getTokenDecimals(address tokenAddress)`

Gets token decimals, defaults to 18 if call fails.

---

## Constants

### Aerodrome

- `AERODROME_ROUTER`: `0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43`
- `AERODROME_FACTORY`: `0x420DD381b31aEf6683db6B902084cB0FFECe40Da`

### Morpho Bundler

- `ADAPTER_ADDRESS`: `0xb98c948CFA24072e58935BC004a8A7b376AE746A`
- `BUNDLER_ADDRESS`: `0x6BFd8137e702540E7A42B74178A4a49Ba43920C4`

### Merkl

- `MERKL_DISTRIBUTOR`: `0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae`

### Configuration

- `SLIPPAGE_TOLERANCE`: 500 (5% in basis points)
- Default `minProfitForFee`: 10e6 ($10 USDC)

---

## Events Reference

### Factory Events

- `VaultDeployed(address indexed vaultAddress, address indexed owner, address indexed admin, bytes32 salt, uint256 chainId)`
- `VaultRegistered(address indexed vaultAddress, address indexed owner, uint256 indexed chainId)`

### Vault Events

#### Asset Management
- `AssetAdded(address indexed asset, address indexed initialVault)`
- `AssetRemoved(address indexed asset)`
- `AssetVaultUpdated(address indexed asset, address indexed oldVault, address indexed newVault)`
- `VaultAdded(address indexed vault)`
- `VaultRemoved(address indexed vault)`

#### Deposits/Withdrawals
- `InitialDeposit(address indexed asset, address indexed vault, uint256 amount)`
- `UserDeposit(address indexed asset, address indexed vault, uint256 amount)`
- `Withdrawal(address indexed asset, address indexed vault, address indexed recipient, uint256 amount)`

#### Rebalancing
- `Rebalanced(address indexed asset, address indexed fromVault, address indexed toVault, uint256 amount)`
- `RebalanceFeeCollected(address indexed asset, uint256 profitAmount, uint256 feeAmount, uint256 newBaseAmount)`

#### Fees
- `FeeCollected(address indexed asset, address indexed vault, uint256 feeAmount, uint256 userAmount)`
- `RevenueAddressUpdated(address indexed oldAddress, address indexed newAddress)`
- `FeePercentageUpdated(uint256 oldFee, uint256 newFee)`
- `RebalanceFeePercentageUpdated(uint256 oldFee, uint256 newFee)`
- `MerklClaimFeePercentageUpdated(uint256 oldFee, uint256 newFee)`
- `MinProfitForFeeUpdated(uint256 oldThreshold, uint256 newThreshold)`

#### Merkl
- `MerklOperatorApproved(address indexed admin)`
- `MerklTokensClaimed(address indexed token, uint256 totalAmount, uint256 feeAmount, uint256 userAmount)`

#### Admin
- `AdminUpdated(address indexed oldAdmin, address indexed newAdmin)`
- `AssetSwapped(address indexed fromAsset, address indexed toAsset, uint256 amountIn, uint256 amountOut)`

---

## Access Control Summary

### Owner Only
- `initialDeposit()`
- `userDeposit()`
- `withdraw()`
- `emergencyWithdraw()`
- `emergencyTokenWithdraw()`
- `claimMerklReward()`
- `claimMerklRewardsBatch()`

### Admin Only
- `addAsset()`
- `removeAsset()`
- `updateAssetVault()`
- `addVault()`
- `removeVault()`
- `updateRevenueAddress()`
- `updateFeePercentage()`
- `updateRebalanceFeePercentage()`
- `updateMerklClaimFeePercentage()`
- `updateMinProfitForFee()`
- `updateAdmin()`
- `pause()` / `unpause()`
- `adminDeposit()`
- `rebalanceToVault()`
- `adminClaimMerklReward()`
- `adminClaimMerklRewardsBatch()`

### Factory Owner Only
- `setDeploymentFee()`
- `setFeeRecipient()`
- `pause()` / `unpause()`
- `registerCrossChainVault()`
- `emergencyWithdraw()`

---

## Best Practices

1. **Always approve tokens before depositing**
2. **Check profit before withdrawing to understand fees**
3. **Use view functions to estimate outcomes**
4. **Monitor rebalance opportunities**
5. **Claim Merkl rewards regularly**
6. **Keep track of assetRebalanceBaseAmount for profit calculation**
7. **Test on testnet before mainnet**
8. **Verify contracts on Basescan**
9. **Use pausability in emergencies**
10. **Maintain good admin key security**

---

*Last Updated: November 2024*
*Version: 1.0.0*
