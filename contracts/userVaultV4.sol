// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Interfaces/IMetaMorpho.sol";
import "./Interfaces/IBundler.sol";
import "./Interfaces/IERC20Extended.sol";
import "./Interfaces/IMerklDistributor.sol";

/**
 * @title UserVault_V4
 * @dev Multi-asset individual user vault contract for yield optimization
 * Supports multiple assets (USDC, WETH, WBTC, etc.) with dedicated vaults per asset
 */
contract UserVault_V4 is ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Bundler addresses
    address public constant ADAPTER_ADDRESS = 0xb98c948CFA24072e58935BC004a8A7b376AE746A;
    address public constant BUNDLER_ADDRESS = 0x6BFd8137e702540E7A42B74178A4a49Ba43920C4;

    // Merkl Distributor address
    address public constant MERKL_DISTRIBUTOR = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

    IBundler3 public constant bundler = IBundler3(BUNDLER_ADDRESS);
    IMerklDistributor public constant merklDistributor = IMerklDistributor(MERKL_DISTRIBUTOR);

    // State variables
    address public owner;
    address public admin;

    // Multi-asset support: each asset has its own vault and tracking
    mapping(address => address) public assetToVault; // asset => current active vault for that asset
    mapping(address => address[]) public assetAvailableVaults; // asset => array of all allowed vaults for that asset
    mapping(address => uint256) public assetTotalDeposited; // asset => total deposited amount
    mapping(address => bool) public assetHasInitialDeposit; // asset => initial deposit status
    mapping(address => uint256) public assetLastDepositTime; // asset => last deposit timestamp
    mapping(address => uint256) public assetTotalFeesCollected; // asset => total fees collected

    // Rebalance profit tracking: base amount from which profit is calculated during rebalance
    mapping(address => uint256) public assetRebalanceBaseAmount; // asset => base amount for profit calculation
    mapping(address => uint256) public assetTotalRebalanceFees; // asset => total rebalance fees collected

    // Allowed assets and vaults with index tracking for O(1) removal
    mapping(address => bool) public isAllowedAsset;
    mapping(address => bool) public isAllowedVault;
    mapping(address => uint256) private assetIndex; // asset => index in allowedAssets array
    mapping(address => uint256) private vaultIndex; // vault => index in allowedVaults array
    address[] public allowedAssets;
    address[] public allowedVaults;

    // Fee configuration
    uint256 public constant MAX_FEE_PERCENTAGE = 3000; // Maximum 30% fee in basis points
    uint256 public constant DEFAULT_FEE_PERCENTAGE = 1000; // Default 10% fee in basis points

    // Ownership transfer
    address public pendingOwner;

    address public revenueAddress;
    uint256 public feePercentage = DEFAULT_FEE_PERCENTAGE; // Fee percentage in basis points (default 10%)
    uint256 public rebalanceFeePercentage = DEFAULT_FEE_PERCENTAGE; // Rebalance fee percentage in basis points (default 10%)
    uint256 public merklClaimFeePercentage = DEFAULT_FEE_PERCENTAGE; // Merkl claim fee percentage in basis points (default 10%)

    // Merkl operator approval status
    bool public adminApprovedForMerkl;

    // Events
    event AssetAdded(address indexed asset, address indexed initialVault);
    event AssetRemoved(address indexed asset);
    event AssetVaultUpdated(address indexed asset, address indexed oldVault, address indexed newVault);
    event InitialDeposit(address indexed asset, address indexed vault, uint256 amount);
    event UserDeposit(address indexed asset, address indexed vault, uint256 amount);
    event Withdrawal(
        address indexed asset,
        address indexed vault,
        address indexed recipient,
        uint256 amount
    );
    event VaultAdded(address indexed vault);
    event VaultRemoved(address indexed vault);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event Rebalanced(
        address indexed asset,
        address indexed fromVault,
        address indexed toVault,
        uint256 amount
    );
    event RebalanceFeeCollected(
        address indexed asset,
        uint256 profitAmount,
        uint256 feeAmount,
        uint256 newBaseAmount
    );
    event RevenueAddressUpdated(
        address indexed oldAddress,
        address indexed newAddress
    );
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event RebalanceFeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event MerklClaimFeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event FeeCollected(
        address indexed asset,
        address indexed vault,
        uint256 feeAmount,
        uint256 userAmount
    );

    // Merkl events
    event MerklOperatorApproved(address indexed admin);
    event MerklTokensClaimed(address indexed token, uint256 totalAmount, uint256 feeAmount, uint256 userAmount);
    event MerklOperatorReapproved(address indexed admin);
    event OwnershipTransferInitiated(address indexed currentOwner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Constructor for multi-asset vault with multi-vault support per asset
     * @param _owner The owner of the vault (user)
     * @param _admin The admin who manages the vault
     * @param _assets Array of initial assets to support (e.g., [USDC, WETH, WBTC])
     * @param _assetVaults 2D array of vaults for each asset. Each asset can have multiple vaults.
     *        Example: [[USDC_Vault1, USDC_Vault2], [WETH_Vault1, WETH_Vault2, WETH_Vault3]]
     *        The first vault in each sub-array becomes the active/primary vault for that asset
     * @param _revenueAddress Address to receive fees
     */
    constructor(
        address _owner,
        address _admin,
        address[] memory _assets,
        address[][] memory _assetVaults,
        address _revenueAddress
    ) {
        require(_owner != address(0), "Invalid owner");
        require(_admin != address(0), "Invalid admin");
        require(_assets.length > 0, "No initial assets");
        require(_assets.length == _assetVaults.length, "Assets and vaults length mismatch");
        require(_revenueAddress != address(0), "Invalid revenue address");

        owner = _owner;
        admin = _admin;
        revenueAddress = _revenueAddress;
        // Fee percentages use DEFAULT_FEE_PERCENTAGE (10%) as default values

        // Add initial assets and their vaults (multi-vault support)
        for (uint256 i = 0; i < _assets.length; i++) {
            require(_assets[i] != address(0), "Invalid asset address");
            require(!isAllowedAsset[_assets[i]], "Duplicate asset");
            require(_assetVaults[i].length > 0, "Each asset must have at least one vault");

            // Mark asset as allowed and track index
            isAllowedAsset[_assets[i]] = true;
            assetIndex[_assets[i]] = allowedAssets.length;
            allowedAssets.push(_assets[i]);

            // Set the first vault as the active/primary vault for this asset
            assetToVault[_assets[i]] = _assetVaults[i][0];

            // Store all vaults for this asset and validate them
            for (uint256 j = 0; j < _assetVaults[i].length; j++) {
                address vault = _assetVaults[i][j];
                require(vault != address(0), "Invalid vault address");

                // Verify vault accepts this asset
                require(IMetaMorpho(vault).asset() == _assets[i], "Vault asset mismatch");

                // Check for duplicate vaults for this asset
                for (uint256 k = 0; k < j; k++) {
                    require(_assetVaults[i][k] != vault, "Duplicate vault for asset");
                }

                assetAvailableVaults[_assets[i]].push(vault);

                // Add vault to allowed vaults whitelist if not already added
                if (!isAllowedVault[vault]) {
                    isAllowedVault[vault] = true;
                    vaultIndex[vault] = allowedVaults.length;
                    allowedVaults.push(vault);
                }
            }
        }
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyAllowedAsset(address asset) {
        require(isAllowedAsset[asset], "Asset not allowed");
        _;
    }

    modifier onlyAllowedVault(address vault) {
        require(isAllowedVault[vault], "Vault not allowed");
        _;
    }

    /**
     * @dev Approve admin as Merkl operator during first deposit
     */
    function _approveMerklOperator() internal {
        if (!adminApprovedForMerkl) {
            merklDistributor.toggleOperator(address(this), admin);
            adminApprovedForMerkl = true;
            emit MerklOperatorApproved(admin);
        }
    }

    /**
     * @dev Deposit to vault using bundler
     * @param vault The vault address to deposit into
     * @param amount The amount of assets to deposit
     * @param vaultAsset The asset token address for the vault
     */
    function _depositToVaultViaBundler(
        address vault,
        uint256 amount,
        address vaultAsset
    ) internal {
        // Approve the adapter to spend tokens (using forceApprove for USDT compatibility)
        IERC20(vaultAsset).forceApprove(ADAPTER_ADDRESS, amount);

        // Calculate max share price with slippage protection (10% tolerance)
        // Get current share price: assets per share = convertToAssets(1e18) for 18 decimal shares
        uint256 currentSharePrice = IMetaMorpho(vault).convertToAssets(1e18);
        // maxSharePriceE27 = price * 1e27 / 1e18 = price * 1e9, with 10% slippage tolerance
        uint256 maxSharePriceE27 = (currentSharePrice * 1e9 * 11000) / 10000;

        // Create calls array
        Call[] memory calls = new Call[](2);

        // First call: erc20TransferFrom - transfer tokens from this contract to adapter
        calls[0] = Call({
            to: ADAPTER_ADDRESS,
            data: abi.encodeWithSelector(
                bytes4(0xd96ca0b9), // erc20TransferFrom selector
                vaultAsset,          // token address
                ADAPTER_ADDRESS,     // receiver (adapter)
                amount              // amount
            ),
            value: 0,
            skipRevert: false,
            callbackHash: bytes32(0)
        });

        // Second call: erc4626Deposit - deposit into vault with slippage protection
        calls[1] = Call({
            to: ADAPTER_ADDRESS,
            data: abi.encodeWithSelector(
                bytes4(0x6ef5eeae), // erc4626Deposit selector
                vault,               // vault address
                amount,              // assets
                maxSharePriceE27,    // maxSharePriceE27 with slippage protection
                address(this)       // receiver (this contract receives the shares)
            ),
            value: 0,
            skipRevert: false,
            callbackHash: bytes32(0)
        });

        // Execute multicall
        bundler.multicall(calls);
    }

    /**
     * @dev Redeem from vault using bundler
     * @param vault The vault address to redeem from
     * @param shares The amount of shares to redeem
     * @return The amount of assets received
     */
    function _redeemFromVaultViaBundler(address vault, uint256 shares)
        internal
        returns (uint256)
    {
        // Get the amount of assets we expect to receive
        uint256 expectedAssets = IMetaMorpho(vault).previewRedeem(shares);

        // Approve the adapter to spend the shares (using forceApprove for compatibility)
        IERC20(vault).forceApprove(ADAPTER_ADDRESS, shares);

        // Calculate min share price with slippage protection (10% tolerance)
        // Get current share price: assets per share = convertToAssets(1e18) for 18 decimal shares
        uint256 currentSharePrice = IMetaMorpho(vault).convertToAssets(1e18);
        // minSharePriceE27 = price * 1e27 / 1e18 = price * 1e9, with 10% slippage tolerance
        uint256 minSharePriceE27 = (currentSharePrice * 1e9 * 9000) / 10000;

        // Create calls array
        Call[] memory calls = new Call[](2);

        // First call: erc20TransferFrom - transfer vault shares from this contract to adapter
        calls[0] = Call({
            to: ADAPTER_ADDRESS,
            data: abi.encodeWithSelector(
                bytes4(0xd96ca0b9), // erc20TransferFrom selector
                vault,               // token address (vault contract = shares token)
                ADAPTER_ADDRESS,     // receiver (adapter needs the shares)
                shares              // amount of shares
            ),
            value: 0,
            skipRevert: false,
            callbackHash: bytes32(0)
        });

        // Second call: erc4626Redeem - redeem from vault with slippage protection
        calls[1] = Call({
            to: ADAPTER_ADDRESS,
            data: abi.encodeWithSelector(
                bytes4(0xa7f6e606), // erc4626Redeem selector
                vault,               // vault address
                shares,              // shares to redeem
                minSharePriceE27,    // minSharePriceE27 with slippage protection
                address(this),       // receiver of assets (this contract)
                ADAPTER_ADDRESS      // owner of shares (adapter has them now)
            ),
            value: 0,
            skipRevert: false,
            callbackHash: bytes32(0)
        });

        // Execute multicall
        bundler.multicall(calls);

        // Return the expected assets
        return expectedAssets;
    }

    // ============ Admin Functions ============

    /**
     * @dev Add a new asset with its vault
     */
    function addAsset(address asset, address vault) external onlyAdmin {
        require(asset != address(0), "Invalid asset address");
        require(vault != address(0), "Invalid vault address");
        require(!isAllowedAsset[asset], "Asset already exists");
        require(isAllowedVault[vault], "Vault not in whitelist");

        // Verify vault accepts this asset
        require(IMetaMorpho(vault).asset() == asset, "Vault asset mismatch");

        isAllowedAsset[asset] = true;
        assetIndex[asset] = allowedAssets.length;
        allowedAssets.push(asset);
        assetToVault[asset] = vault;

        emit AssetAdded(asset, vault);
    }

    /**
     * @dev Remove an asset (only if no deposits exist)
     * @notice Uses O(1) removal via index mapping
     */
    function removeAsset(address asset) external onlyAdmin {
        require(isAllowedAsset[asset], "Asset not allowed");
        require(!assetHasInitialDeposit[asset], "Asset has deposits");

        isAllowedAsset[asset] = false;

        // O(1) removal using index mapping
        uint256 idx = assetIndex[asset];
        uint256 lastIdx = allowedAssets.length - 1;
        if (idx != lastIdx) {
            address lastAsset = allowedAssets[lastIdx];
            allowedAssets[idx] = lastAsset;
            assetIndex[lastAsset] = idx;
        }
        allowedAssets.pop();
        delete assetIndex[asset];

        delete assetToVault[asset];

        emit AssetRemoved(asset);
    }

    /**
     * @dev Remove a vault from the whitelist
     * @notice Uses O(1) removal via index mapping
     */
    function removeVault(address vault) external onlyAdmin {
        require(isAllowedVault[vault], "Vault not allowed");

        // Check if any asset is using this vault
        for (uint256 i = 0; i < allowedAssets.length; i++) {
            require(assetToVault[allowedAssets[i]] != vault, "Vault in use");
        }

        isAllowedVault[vault] = false;

        // O(1) removal using index mapping
        uint256 idx = vaultIndex[vault];
        uint256 lastIdx = allowedVaults.length - 1;
        if (idx != lastIdx) {
            address lastVault = allowedVaults[lastIdx];
            allowedVaults[idx] = lastVault;
            vaultIndex[lastVault] = idx;
        }
        allowedVaults.pop();
        delete vaultIndex[vault];

        emit VaultRemoved(vault);
    }

    /**
     * @dev Update revenue address
     */
    function updateRevenueAddress(address newRevenueAddress)
        external
        onlyAdmin
    {
        require(newRevenueAddress != address(0), "Invalid revenue address");
        address oldAddress = revenueAddress;
        revenueAddress = newRevenueAddress;
        emit RevenueAddressUpdated(oldAddress, newRevenueAddress);
    }

    /**
     * @dev Update fee percentage for withdrawal fees
     */
    function updateFeePercentage(uint256 newFeePercentage) external onlyAdmin {
        require(newFeePercentage <= MAX_FEE_PERCENTAGE, "Fee exceeds maximum");
        uint256 oldFee = feePercentage;
        feePercentage = newFeePercentage;
        emit FeePercentageUpdated(oldFee, newFeePercentage);
    }

    /**
     * @dev Update rebalance fee percentage
     */
    function updateRebalanceFeePercentage(uint256 newRebalanceFeePercentage) external onlyAdmin {
        require(newRebalanceFeePercentage <= MAX_FEE_PERCENTAGE, "Fee exceeds maximum");
        uint256 oldFee = rebalanceFeePercentage;
        rebalanceFeePercentage = newRebalanceFeePercentage;
        emit RebalanceFeePercentageUpdated(oldFee, newRebalanceFeePercentage);
    }

    /**
     * @dev Update Merkl claim fee percentage
     */
    function updateMerklClaimFeePercentage(uint256 newMerklClaimFeePercentage) external onlyAdmin {
        require(newMerklClaimFeePercentage <= MAX_FEE_PERCENTAGE, "Fee exceeds maximum");
        uint256 oldFee = merklClaimFeePercentage;
        merklClaimFeePercentage = newMerklClaimFeePercentage;
        emit MerklClaimFeePercentageUpdated(oldFee, newMerklClaimFeePercentage);
    }

    /**
     * @dev Update admin address
     */
    function updateAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid admin address");
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminUpdated(oldAdmin, newAdmin);
    }

    /**
     * @dev Initiate ownership transfer (two-step process for safety)
     * @param newOwner The address to transfer ownership to
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        require(newOwner != owner, "Already the owner");
        pendingOwner = newOwner;
        emit OwnershipTransferInitiated(owner, newOwner);
    }

    /**
     * @dev Accept ownership transfer (must be called by pending owner)
     */
    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "Not pending owner");
        address oldOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, owner);
    }

    /**
     * @dev Cancel pending ownership transfer
     */
    function cancelOwnershipTransfer() external onlyOwner {
        require(pendingOwner != address(0), "No pending transfer");
        pendingOwner = address(0);
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyAdmin {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyAdmin {
        _unpause();
    }

    // ============ Deposit Functions ============

    /**
     * @dev Initial deposit for a specific asset
     * @param asset The asset to deposit
     * @param vault The vault to deposit into (must be in assetAvailableVaults for this asset)
     * @param amount Amount to deposit
     */
    function initialDeposit(address asset, address vault, uint256 amount)
        external
        onlyOwner
        onlyAllowedAsset(asset)
        nonReentrant
        whenNotPaused
    {
        require(!assetHasInitialDeposit[asset], "Initial deposit already made for this asset");
        require(amount > 0, "Amount must be positive");
        require(vault != address(0), "Invalid vault address");
        require(isVaultAvailableForAsset(asset, vault), "Vault not available for this asset");

        // Approve admin as Merkl operator on first deposit (any asset)
        _approveMerklOperator();

        // Transfer asset from user to this contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Deposit to vault using bundler
        _depositToVaultViaBundler(vault, amount, asset);

        // Set the chosen vault as the active vault for this asset
        assetToVault[asset] = vault;

        // Set state for this asset
        assetTotalDeposited[asset] = amount;
        assetHasInitialDeposit[asset] = true;
        assetLastDepositTime[asset] = block.timestamp;
        assetRebalanceBaseAmount[asset] = amount; // Set initial base amount for rebalance profit calculation

        emit InitialDeposit(asset, vault, amount);
    }

    /**
     * @dev User deposit function - allows owner to deposit more of a specific asset
     * @param asset The asset to deposit
     * @param amount Amount to deposit
     */
    function userDeposit(address asset, uint256 amount)
        external
        onlyOwner
        onlyAllowedAsset(asset)
        nonReentrant
        whenNotPaused
    {
        require(assetHasInitialDeposit[asset], "Initial deposit not made for this asset");
        require(amount > 0, "Amount must be positive");

        address vault = assetToVault[asset];
        require(vault != address(0), "No vault set for asset");

        // Transfer asset from user to this contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Deposit to vault using bundler
        _depositToVaultViaBundler(vault, amount, asset);

        // Update tracking
        assetTotalDeposited[asset] += amount;
        assetLastDepositTime[asset] = block.timestamp;
        assetRebalanceBaseAmount[asset] += amount; // Increase base amount for rebalance profit calculation

        emit UserDeposit(asset, vault, amount);
    }

    /**
     * @dev Admin deposit function - allows admin to deposit on behalf of user
     * @param asset The asset to deposit
     * @param amount Amount to deposit
     */
    function adminDeposit(address asset, uint256 amount)
        external
        onlyAdmin
        onlyAllowedAsset(asset)
        nonReentrant
        whenNotPaused
    {
        require(assetHasInitialDeposit[asset], "Initial deposit not made for this asset");
        require(amount > 0, "Amount must be positive");

        address vault = assetToVault[asset];
        require(vault != address(0), "No vault set for asset");

        // Transfer asset from admin to this contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Deposit to vault using bundler
        _depositToVaultViaBundler(vault, amount, asset);

        // Update tracking
        assetTotalDeposited[asset] += amount;
        assetLastDepositTime[asset] = block.timestamp;
        assetRebalanceBaseAmount[asset] += amount; // Increase base amount for rebalance profit calculation

        emit UserDeposit(asset, vault, amount);
    }

    // ============ Withdrawal Functions ============

    /**
     * @dev Withdraw from a specific asset's vault
     * @param asset The asset to withdraw
     * @param amount Amount of shares to withdraw (0 for full withdrawal)
     */
    function withdraw(address asset, uint256 amount)
        external
        onlyOwner
        onlyAllowedAsset(asset)
        nonReentrant
        whenNotPaused
    {
        require(assetHasInitialDeposit[asset], "No deposits for this asset");

        address vault = assetToVault[asset];
        uint256 vaultBalance = _getVaultBalance(vault);
        require(vaultBalance > 0, "No funds in vault");

        uint256 withdrawAmount = amount;
        if (amount == 0 || amount > vaultBalance) {
            withdrawAmount = vaultBalance; // Full withdrawal
        }

        // Redeem from vault using bundler
        uint256 redeemedAmount = _redeemFromVaultViaBundler(vault, withdrawAmount);

        // Calculate fee and user amount
        (uint256 feeAmount, uint256 userAmount) = calculateFeeFromProfit(
            asset,
            redeemedAmount
        );

        // Transfer fee to revenue address if there's a fee
        if (feeAmount > 0) {
            IERC20(asset).safeTransfer(revenueAddress, feeAmount);
            assetTotalFeesCollected[asset] += feeAmount;
            emit FeeCollected(asset, vault, feeAmount, userAmount);
        }

        // Transfer remaining amount to owner
        IERC20(asset).safeTransfer(owner, userAmount);

        // Update total deposited
        assetTotalDeposited[asset] = assetTotalDeposited[asset] > redeemedAmount
            ? assetTotalDeposited[asset] - redeemedAmount
            : 0;

        emit Withdrawal(asset, vault, owner, userAmount);
    }

    /**
     * @dev Emergency withdraw for a specific asset when paused
     */
    function emergencyWithdraw(address asset)
        external
        onlyOwner
        onlyAllowedAsset(asset)
        whenPaused
        nonReentrant
    {
        address vault = assetToVault[asset];
        require(vault != address(0), "No vault for asset");

        uint256 balance = _getVaultBalance(vault);
        if (balance > 0) {
            uint256 redeemedAmount = _redeemFromVaultViaBundler(vault, balance);

            // Calculate fee and user amount
            (uint256 feeAmount, uint256 userAmount) = calculateFeeFromProfit(
                asset,
                redeemedAmount
            );

            // Transfer fee to revenue address if there's a fee
            if (feeAmount > 0) {
                IERC20(asset).safeTransfer(revenueAddress, feeAmount);
                assetTotalFeesCollected[asset] += feeAmount;
                emit FeeCollected(asset, vault, feeAmount, userAmount);
            }

            // Transfer remaining amount to owner
            IERC20(asset).safeTransfer(owner, userAmount);
            assetTotalDeposited[asset] = 0;

            emit Withdrawal(asset, vault, owner, userAmount);
        }
    }

    // ============ Rebalance Functions ============

    /**
     * @dev Rebalance a specific asset to a new vault (must be in available vaults for that asset)
     * @param asset The asset to rebalance
     * @param toVault The new vault to deposit into (must be in assetAvailableVaults)
     */
    function rebalanceToVault(address asset, address toVault)
        external
        onlyAdmin
        onlyAllowedAsset(asset)
        onlyAllowedVault(toVault)
        nonReentrant
        whenNotPaused
    {
        require(assetHasInitialDeposit[asset], "No deposits for this asset");
        require(isVaultAvailableForAsset(asset, toVault), "Vault not available for this asset");

        address fromVault = assetToVault[asset];
        require(fromVault != toVault, "Same vault");
        require(IMetaMorpho(toVault).asset() == asset, "Vault asset mismatch");

        uint256 balance = _getVaultBalance(fromVault);
        require(balance > 0, "No funds to rebalance");

        // Redeem from current vault
        uint256 redeemedAmount = _redeemFromVaultViaBundler(fromVault, balance);

        // Calculate profit and deduct 10% fee if there's profit
        uint256 baseAmount = assetRebalanceBaseAmount[asset];
        uint256 amountToDeposit = redeemedAmount;
        uint256 feeAmount = 0;

        if (redeemedAmount > baseAmount && baseAmount > 0) {
            // There's profit, calculate rebalance fee on profit
            uint256 profit = redeemedAmount - baseAmount;
            feeAmount = (profit * rebalanceFeePercentage) / 10000;

            // Transfer fee to revenue address
            if (feeAmount > 0) {
                IERC20(asset).safeTransfer(revenueAddress, feeAmount);
                assetTotalRebalanceFees[asset] += feeAmount;
            }

            // Amount to deposit is redeemed amount minus fee
            amountToDeposit = redeemedAmount - feeAmount;

            // Update base amount to new amount (after fee deduction)
            assetRebalanceBaseAmount[asset] = amountToDeposit;

            emit RebalanceFeeCollected(asset, profit, feeAmount, amountToDeposit);
        } else {
            // No profit or loss, update base amount to current amount
            assetRebalanceBaseAmount[asset] = redeemedAmount;
        }

        // Deposit into new vault (amount after fee deduction if applicable)
        _depositToVaultViaBundler(toVault, amountToDeposit, asset);

        // Update current vault for this asset
        assetToVault[asset] = toVault;

        emit Rebalanced(asset, fromVault, toVault, amountToDeposit);
    }

    // ============ Fee Calculation ============

    /**
     * @dev Calculate fee amount from profit for a specific asset
     * @notice Fee is only charged on profit, not on principal
     * @param asset The asset to calculate fees for
     * @param totalAmount The total amount being withdrawn
     */
    function calculateFeeFromProfit(address asset, uint256 totalAmount)
        public
        view
        returns (uint256 feeAmount, uint256 userAmount)
    {
        if (!assetHasInitialDeposit[asset] || assetTotalDeposited[asset] == 0 || totalAmount <= assetTotalDeposited[asset]) {
            // NO PROFIT = NO FEE
            return (0, totalAmount);
        }

        // Calculate profit
        uint256 profit = totalAmount - assetTotalDeposited[asset];

        // Charge fee only on the profit portion
        feeAmount = (profit * feePercentage) / 10000;
        userAmount = totalAmount - feeAmount;

        return (feeAmount, userAmount);
    }

    // ============ View Functions ============

    /**
     * @dev Get vault balance for a specific vault
     */
    function _getVaultBalance(address vault) internal view returns (uint256) {
        return IMetaMorpho(vault).balanceOf(address(this));
    }

    /**
     * @dev Get current vault balance for an asset
     */
    function getAssetVaultBalance(address asset) external view returns (uint256) {
        if (!isAllowedAsset[asset]) return 0;
        address vault = assetToVault[asset];
        if (vault == address(0)) return 0;
        return _getVaultBalance(vault);
    }

    /**
     * @dev Get current vault assets (underlying tokens) for an asset
     */
    function getAssetVaultAssets(address asset) external view returns (uint256) {
        if (!isAllowedAsset[asset]) return 0;
        address vault = assetToVault[asset];
        if (vault == address(0)) return 0;
        uint256 shares = _getVaultBalance(vault);
        return IMetaMorpho(vault).convertToAssets(shares);
    }

    /**
     * @dev Get profit for a specific asset
     */
    function getAssetProfit(address asset) external view returns (int256) {
        if (!assetHasInitialDeposit[asset] || assetTotalDeposited[asset] == 0) return 0;

        uint256 currentValue = this.getAssetVaultAssets(asset);

        if (currentValue >= assetTotalDeposited[asset]) {
            return int256(currentValue - assetTotalDeposited[asset]);
        } else {
            return -int256(assetTotalDeposited[asset] - currentValue);
        }
    }

    /**
     * @dev Get profit percentage for a specific asset (with 6 decimals precision)
     */
    function getAssetProfitPercentage(address asset) external view returns (int256) {
        if (!assetHasInitialDeposit[asset] || assetTotalDeposited[asset] == 0) return 0;

        uint256 currentValue = this.getAssetVaultAssets(asset);

        if (currentValue >= assetTotalDeposited[asset]) {
            uint256 profit = currentValue - assetTotalDeposited[asset];
            return int256((profit * 1000000) / assetTotalDeposited[asset]);
        } else {
            uint256 loss = assetTotalDeposited[asset] - currentValue;
            return -int256((loss * 1000000) / assetTotalDeposited[asset]);
        }
    }

    /**
     * @dev Get all allowed assets
     */
    function getAllowedAssets() external view returns (address[] memory) {
        return allowedAssets;
    }

    /**
     * @dev Get all allowed vaults
     */
    function getAllowedVaults() external view returns (address[] memory) {
        return allowedVaults;
    }

    /**
     * @dev Get summary of all assets with deposits
     */
    function getPortfolioSummary()
        external
        view
        returns (
            address[] memory assets,
            uint256[] memory deposited,
            uint256[] memory currentValues,
            int256[] memory profits
        )
    {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allowedAssets.length; i++) {
            if (assetHasInitialDeposit[allowedAssets[i]]) {
                activeCount++;
            }
        }

        assets = new address[](activeCount);
        deposited = new uint256[](activeCount);
        currentValues = new uint256[](activeCount);
        profits = new int256[](activeCount);

        uint256 index = 0;
        for (uint256 i = 0; i < allowedAssets.length; i++) {
            address asset = allowedAssets[i];
            if (assetHasInitialDeposit[asset]) {
                assets[index] = asset;
                deposited[index] = assetTotalDeposited[asset];
                currentValues[index] = this.getAssetVaultAssets(asset);
                profits[index] = this.getAssetProfit(asset);
                index++;
            }
        }

        return (assets, deposited, currentValues, profits);
    }

    /**
     * @dev Get rebalance base amount for a specific asset
     */
    function getAssetRebalanceBaseAmount(address asset) external view returns (uint256) {
        return assetRebalanceBaseAmount[asset];
    }

    /**
     * @dev Get current rebalance profit for a specific asset (unrealized)
     * @return profit The profit amount (can be negative for loss)
     */
    function getAssetRebalanceProfit(address asset) external view returns (int256 profit) {
        if (!assetHasInitialDeposit[asset] || assetRebalanceBaseAmount[asset] == 0) {
            return 0;
        }

        uint256 currentValue = this.getAssetVaultAssets(asset);
        uint256 baseAmount = assetRebalanceBaseAmount[asset];

        if (currentValue >= baseAmount) {
            return int256(currentValue - baseAmount);
        } else {
            return -int256(baseAmount - currentValue);
        }
    }

    /**
     * @dev Get total rebalance fees collected for an asset
     */
    function getAssetTotalRebalanceFees(address asset) external view returns (uint256) {
        return assetTotalRebalanceFees[asset];
    }

    /**
     * @dev Get rebalance info for a specific asset
     * @return baseAmount The current base amount used for profit calculation
     * @return currentValue The current value in the vault
     * @return profit The unrealized profit/loss
     * @return totalFees The total rebalance fees collected
     */
    function getAssetRebalanceInfo(address asset)
        external
        view
        returns (
            uint256 baseAmount,
            uint256 currentValue,
            int256 profit,
            uint256 totalFees
        )
    {
        baseAmount = assetRebalanceBaseAmount[asset];
        currentValue = this.getAssetVaultAssets(asset);
        profit = this.getAssetRebalanceProfit(asset);
        totalFees = assetTotalRebalanceFees[asset];

        return (baseAmount, currentValue, profit, totalFees);
    }

    /**
     * @dev Get token decimals
     */
    function _getTokenDecimals(address tokenAddress)
        internal
        view
        returns (uint256)
    {
        try IERC20Extended(tokenAddress).decimals() returns (uint8 decimals) {
            return uint256(decimals);
        } catch {
            return 18; // Default to 18 decimals
        }
    }

    /**
     * @dev Get fee information
     */
    function getFeeInfo()
        external
        view
        returns (
            address _revenueAddress,
            uint256 _feePercentage,
            uint256 _rebalanceFeePercentage,
            uint256 _merklClaimFeePercentage
        )
    {
        return (revenueAddress, feePercentage, rebalanceFeePercentage, merklClaimFeePercentage);
    }

    /**
     * @dev Get total fees collected for an asset
     */
    function getAssetFeesCollected(address asset) external view returns (uint256) {
        return assetTotalFeesCollected[asset];
    }

    /**
     * @dev Get all available vaults for a specific asset
     */
    function getAssetAvailableVaults(address asset) external view returns (address[] memory) {
        return assetAvailableVaults[asset];
    }

    /**
     * @dev Get the active/primary vault for a specific asset
     */
    function getAssetActiveVault(address asset) external view returns (address) {
        return assetToVault[asset];
    }

    /**
     * @dev Check if a vault is available for a specific asset
     */
    function isVaultAvailableForAsset(address asset, address vault) public view returns (bool) {
        address[] memory vaults = assetAvailableVaults[asset];
        for (uint256 i = 0; i < vaults.length; i++) {
            if (vaults[i] == vault) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Add a new vault to an asset's available vaults list
     * @notice Automatically adds vault to global whitelist if not already present
     * @param asset The asset address
     * @param vault The vault address to add
     */
    function addVaultToAsset(address asset, address vault)
        external
        onlyAdmin
        onlyAllowedAsset(asset)
    {
        require(vault != address(0), "Invalid vault address");
        require(IMetaMorpho(vault).asset() == asset, "Vault asset mismatch");
        require(!isVaultAvailableForAsset(asset, vault), "Vault already available for asset");

        // Automatically add to global whitelist if not already present
        if (!isAllowedVault[vault]) {
            isAllowedVault[vault] = true;
            vaultIndex[vault] = allowedVaults.length;
            allowedVaults.push(vault);
        }

        // Add to asset's available vaults
        assetAvailableVaults[asset].push(vault);

        emit VaultAdded(vault);
    }

    /**
     * @dev Remove a vault from an asset's available vaults list
     * @param asset The asset address
     * @param vault The vault address to remove
     */
    function removeVaultFromAsset(address asset, address vault)
        external
        onlyAdmin
        onlyAllowedAsset(asset)
    {
        require(vault != assetToVault[asset], "Cannot remove active vault");
        require(isVaultAvailableForAsset(asset, vault), "Vault not available for asset");

        address[] storage vaults = assetAvailableVaults[asset];
        for (uint256 i = 0; i < vaults.length; i++) {
            if (vaults[i] == vault) {
                vaults[i] = vaults[vaults.length - 1];
                vaults.pop();
                break;
            }
        }

        emit VaultRemoved(vault);
    }

    /**
     * @dev Set the active/primary vault for an asset from its available vaults
     * @param asset The asset address
     * @param newActiveVault The new active vault (must be in available vaults)
     */
    function setAssetActiveVault(address asset, address newActiveVault)
        external
        onlyAdmin
        onlyAllowedAsset(asset)
    {
        require(newActiveVault != address(0), "Invalid vault");
        require(isVaultAvailableForAsset(asset, newActiveVault), "Vault not available for this asset");
        require(assetToVault[asset] != newActiveVault, "Already active vault");

        address oldVault = assetToVault[asset];
        assetToVault[asset] = newActiveVault;

        emit AssetVaultUpdated(asset, oldVault, newActiveVault);
    }

    // ============ Merkl Functions ============

    /**
     * @dev Check if admin is approved as Merkl operator
     */
    function isAdminApprovedForMerkl() external view returns (bool) {
        return merklDistributor.operators(address(this), admin) == 1;
    }

    /**
     * @dev Claim single Merkl reward token
     * @dev Deducts merklClaimFeePercentage from claimed amount, sends fee to revenueAddress and rest to owner
     * @param token The reward token address to claim
     * @param claimable The amount to claim (from Merkl proof)
     * @param proof The Merkle proof for claiming
     */
    function claimMerklReward(
        address token,
        uint256 claimable,
        bytes32[] calldata proof
    ) external onlyOwner nonReentrant {
        require(token != address(0), "Invalid token address");
        require(claimable > 0, "Nothing to claim");

        // Prepare arrays for batch call (single item)
        address[] memory users = new address[](1);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        bytes32[][] memory proofs = new bytes32[][](1);

        users[0] = address(this);
        tokens[0] = token;
        amounts[0] = claimable;
        proofs[0] = proof;

        // Get balance before claim
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));

        // Claim rewards
        merklDistributor.claim(users, tokens, amounts, proofs);

        // Calculate claimed amount
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        uint256 claimedAmount = balanceAfter - balanceBefore;

        // Split claimed reward: fee to revenueAddress, rest to owner
        if (claimedAmount > 0) {
            uint256 feeAmount = (claimedAmount * merklClaimFeePercentage) / 10000;
            uint256 userAmount = claimedAmount - feeAmount;

            // Transfer fee to revenue address
            if (feeAmount > 0) {
                IERC20(token).safeTransfer(revenueAddress, feeAmount);
            }

            // Transfer remaining to owner
            if (userAmount > 0) {
                IERC20(token).safeTransfer(owner, userAmount);
            }

            emit MerklTokensClaimed(token, claimedAmount, feeAmount, userAmount);
        }
    }

    /**
     * @dev Claim multiple Merkl reward tokens in a single transaction
     * @dev Deducts merklClaimFeePercentage from each claimed token amount
     * @param tokens Array of reward token addresses to claim
     * @param claimables Array of amounts to claim for each token
     * @param proofs Array of Merkle proofs for each claim
     */
    function claimMerklRewardsBatch(
        address[] calldata tokens,
        uint256[] calldata claimables,
        bytes32[][] calldata proofs
    ) external onlyOwner nonReentrant {
        require(tokens.length == claimables.length, "Array length mismatch");
        require(tokens.length == proofs.length, "Array length mismatch");
        require(tokens.length > 0, "Empty arrays");

        // Prepare arrays for batch claim and check for duplicates
        address[] memory accounts = new address[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokens[i] != address(0), "Invalid token address");
            require(claimables[i] > 0, "Nothing to claim");
            // Check for duplicate tokens
            for (uint256 j = 0; j < i; j++) {
                require(tokens[i] != tokens[j], "Duplicate token in batch");
            }
            accounts[i] = address(this);
        }

        // Track balances before
        uint256[] memory balancesBefore = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            balancesBefore[i] = IERC20(tokens[i]).balanceOf(address(this));
        }

        // Execute batch claim
        merklDistributor.claim(accounts, tokens, claimables, proofs);

        // Split each claimed token: fee to revenueAddress, rest to owner
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 balanceAfter = IERC20(tokens[i]).balanceOf(address(this));
            uint256 claimedAmount = balanceAfter - balancesBefore[i];

            if (claimedAmount > 0) {
                uint256 feeAmount = (claimedAmount * merklClaimFeePercentage) / 10000;
                uint256 userAmount = claimedAmount - feeAmount;

                // Transfer fee to revenue address
                if (feeAmount > 0) {
                    IERC20(tokens[i]).safeTransfer(revenueAddress, feeAmount);
                }

                // Transfer remaining to owner
                if (userAmount > 0) {
                    IERC20(tokens[i]).safeTransfer(owner, userAmount);
                }

                emit MerklTokensClaimed(tokens[i], claimedAmount, feeAmount, userAmount);
            }
        }
    }

    /**
     * @dev Admin claim Merkl rewards on behalf of user
     * @dev Deducts merklClaimFeePercentage from claimed amount, sends fee to revenueAddress and rest to owner
     */
    function adminClaimMerklReward(
        address token,
        uint256 claimable,
        bytes32[] calldata proof
    ) external onlyAdmin nonReentrant {
        require(token != address(0), "Invalid token address");
        require(claimable > 0, "Nothing to claim");

        // Prepare arrays
        address[] memory users = new address[](1);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        bytes32[][] memory proofs = new bytes32[][](1);

        users[0] = address(this);
        tokens[0] = token;
        amounts[0] = claimable;
        proofs[0] = proof;

        // Get balance before
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));

        // Claim
        merklDistributor.claim(users, tokens, amounts, proofs);

        // Calculate claimed amount
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        uint256 claimedAmount = balanceAfter - balanceBefore;

        // Split claimed reward: fee to revenueAddress, rest to owner
        if (claimedAmount > 0) {
            uint256 feeAmount = (claimedAmount * merklClaimFeePercentage) / 10000;
            uint256 userAmount = claimedAmount - feeAmount;

            // Transfer fee to revenue address
            if (feeAmount > 0) {
                IERC20(token).safeTransfer(revenueAddress, feeAmount);
            }

            // Transfer remaining to owner
            if (userAmount > 0) {
                IERC20(token).safeTransfer(owner, userAmount);
            }

            emit MerklTokensClaimed(token, claimedAmount, feeAmount, userAmount);
        }
    }

    /**
     * @dev Admin claim multiple Merkl rewards
     */
    function adminClaimMerklRewardsBatch(
        address[] calldata tokens,
        uint256[] calldata claimables,
        bytes32[][] calldata proofs
    ) external onlyAdmin nonReentrant {
        require(tokens.length == claimables.length, "Array length mismatch");
        require(tokens.length == proofs.length, "Array length mismatch");
        require(tokens.length > 0, "Empty arrays");

        // Prepare arrays and check for duplicates
        address[] memory accounts = new address[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokens[i] != address(0), "Invalid token address");
            require(claimables[i] > 0, "Nothing to claim");
            // Check for duplicate tokens
            for (uint256 j = 0; j < i; j++) {
                require(tokens[i] != tokens[j], "Duplicate token in batch");
            }
            accounts[i] = address(this);
        }

        // Track balances before
        uint256[] memory balancesBefore = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            balancesBefore[i] = IERC20(tokens[i]).balanceOf(address(this));
        }

        // Execute batch claim
        merklDistributor.claim(accounts, tokens, claimables, proofs);

        // Split each claimed token: fee to revenueAddress, rest to owner
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 balanceAfter = IERC20(tokens[i]).balanceOf(address(this));
            uint256 claimedAmount = balanceAfter - balancesBefore[i];

            if (claimedAmount > 0) {
                uint256 feeAmount = (claimedAmount * merklClaimFeePercentage) / 10000;
                uint256 userAmount = claimedAmount - feeAmount;

                // Transfer fee to revenue address
                if (feeAmount > 0) {
                    IERC20(tokens[i]).safeTransfer(revenueAddress, feeAmount);
                }

                // Transfer remaining to owner
                if (userAmount > 0) {
                    IERC20(tokens[i]).safeTransfer(owner, userAmount);
                }

                emit MerklTokensClaimed(tokens[i], claimedAmount, feeAmount, userAmount);
            }
        }
    }

    /**
     * @dev Re-approve admin as Merkl operator (useful if admin changed or operator status was revoked)
     * @notice Only callable by owner to ensure security
     */
    function reapproveMerklOperator() external onlyOwner {
        // Check current operator status
        bool currentlyApproved = merklDistributor.operators(address(this), admin) == 1;

        // Toggle operator status (if currently approved, this will revoke and re-approve)
        if (currentlyApproved) {
            merklDistributor.toggleOperator(address(this), admin); // Revoke
        }
        merklDistributor.toggleOperator(address(this), admin); // Approve

        adminApprovedForMerkl = true;
        emit MerklOperatorReapproved(admin);
    }

    // ============ Emergency Functions ============

    /**
     * @dev Get balance of any ERC20 token held by this contract
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @dev Emergency function to withdraw any ERC20 tokens stuck in contract
     */
    function emergencyTokenWithdraw(address token, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(token != address(0), "Invalid token address");

        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");

        uint256 withdrawAmount = amount == 0 ? balance : amount;
        require(withdrawAmount <= balance, "Insufficient balance");

        IERC20(token).safeTransfer(owner, withdrawAmount);
    }
}