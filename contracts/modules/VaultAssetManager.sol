// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./VaultAccessControl.sol";
import "../Interfaces/IMetaMorpho.sol";

/**
 * @title VaultAssetManager
 * @dev Manages assets, vaults, and fee configurations
 * @notice All admin functions are restricted to Gnosis Safe multisig wallet
 */
abstract contract VaultAssetManager is VaultAccessControl {

    // ============ Asset Management (Gnosis Safe Multisig Only) ============

    /**
     * @dev Add a new asset with its vault
     * @notice Only callable by admin (Gnosis Safe multisig)
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
     * @notice Only callable by admin (Gnosis Safe multisig)
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

    // ============ Vault Management (Gnosis Safe Multisig Only) ============

    /**
     * @dev Remove a vault from the whitelist
     * @notice Only callable by admin (Gnosis Safe multisig)
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
     * @dev Add a new vault to an asset's available vaults list
     * @notice Only callable by admin (Gnosis Safe multisig)
     * @notice Automatically adds vault to global whitelist if not already present
     * @notice Uses O(1) index mapping for efficient lookups
     */
    function addVaultToAsset(address asset, address vault)
        external
        onlyAdmin
        onlyAllowedAsset(asset)
    {
        require(vault != address(0), "Invalid vault address");
        require(IMetaMorpho(vault).asset() == asset, "Vault asset mismatch");
        require(!isAssetVaultAvailable[asset][vault], "Vault already available for asset");

        // Automatically add to global whitelist if not already present
        if (!isAllowedVault[vault]) {
            isAllowedVault[vault] = true;
            vaultIndex[vault] = allowedVaults.length;
            allowedVaults.push(vault);
        }

        // Add to asset's available vaults with O(1) tracking
        assetVaultIndex[asset][vault] = assetAvailableVaults[asset].length;
        isAssetVaultAvailable[asset][vault] = true;
        assetAvailableVaults[asset].push(vault);

        emit VaultAdded(vault);
    }

    /**
     * @dev Remove a vault from an asset's available vaults list
     * @notice Only callable by admin (Gnosis Safe multisig)
     * @notice Uses O(1) removal via index mapping
     */
    function removeVaultFromAsset(address asset, address vault)
        external
        onlyAdmin
        onlyAllowedAsset(asset)
    {
        require(vault != assetToVault[asset], "Cannot remove active vault");
        require(isAssetVaultAvailable[asset][vault], "Vault not available for asset");

        // O(1) removal using index mapping
        address[] storage vaults = assetAvailableVaults[asset];
        uint256 idx = assetVaultIndex[asset][vault];
        uint256 lastIdx = vaults.length - 1;

        if (idx != lastIdx) {
            address lastVault = vaults[lastIdx];
            vaults[idx] = lastVault;
            assetVaultIndex[asset][lastVault] = idx;
        }

        vaults.pop();
        delete assetVaultIndex[asset][vault];
        isAssetVaultAvailable[asset][vault] = false;

        emit VaultRemoved(vault);
    }

    /**
     * @dev Set the active/primary vault for an asset from its available vaults
     * @notice Only callable by admin (Gnosis Safe multisig)
     */
    function setAssetActiveVault(address asset, address newActiveVault)
        external
        onlyAdmin
        onlyAllowedAsset(asset)
    {
        require(newActiveVault != address(0), "Invalid vault");
        require(isAssetVaultAvailable[asset][newActiveVault], "Vault not available for this asset");
        require(assetToVault[asset] != newActiveVault, "Already active vault");

        address oldVault = assetToVault[asset];
        assetToVault[asset] = newActiveVault;

        emit AssetVaultUpdated(asset, oldVault, newActiveVault);
    }

    // ============ Fee Configuration (Gnosis Safe Multisig Only, 24-hour cooldown) ============

    /**
     * @dev Update withdrawal fee percentage
     * @notice Only callable by admin (Gnosis Safe multisig)
     * @notice Requires 24-hour cooldown between changes
     * @param newFeePercentage The new fee in basis points (max 10%)
     */
    function updateFeePercentage(uint256 newFeePercentage) external onlyAdmin {
        require(newFeePercentage <= MAX_FEE_PERCENTAGE, "Fee exceeds maximum 10%");
        require(
            block.timestamp >= lastFeePercentageChangeTime + FEE_CHANGE_TIMELOCK,
            "Fee change cooldown not passed (24 hours)"
        );

        uint256 oldFee = feePercentage;
        feePercentage = newFeePercentage;
        lastFeePercentageChangeTime = block.timestamp;

        emit FeePercentageUpdated(oldFee, newFeePercentage);
    }

    /**
     * @dev Update rebalance fee percentage
     * @notice Only callable by admin (Gnosis Safe multisig)
     * @notice Requires 24-hour cooldown between changes
     * @param newFeePercentage The new fee in basis points (max 10%)
     */
    function updateRebalanceFeePercentage(uint256 newFeePercentage) external onlyAdmin {
        require(newFeePercentage <= MAX_FEE_PERCENTAGE, "Fee exceeds maximum 10%");
        require(
            block.timestamp >= lastRebalanceFeePercentageChangeTime + FEE_CHANGE_TIMELOCK,
            "Fee change cooldown not passed (24 hours)"
        );

        uint256 oldFee = rebalanceFeePercentage;
        rebalanceFeePercentage = newFeePercentage;
        lastRebalanceFeePercentageChangeTime = block.timestamp;

        emit RebalanceFeePercentageUpdated(oldFee, newFeePercentage);
    }

    /**
     * @dev Update Merkl claim fee percentage
     * @notice Only callable by admin (Gnosis Safe multisig)
     * @notice Requires 24-hour cooldown between changes
     * @param newFeePercentage The new fee in basis points (max 10%)
     */
    function updateMerklClaimFeePercentage(uint256 newFeePercentage) external onlyAdmin {
        require(newFeePercentage <= MAX_FEE_PERCENTAGE, "Fee exceeds maximum 10%");
        require(
            block.timestamp >= lastMerklClaimFeePercentageChangeTime + FEE_CHANGE_TIMELOCK,
            "Fee change cooldown not passed (24 hours)"
        );

        uint256 oldFee = merklClaimFeePercentage;
        merklClaimFeePercentage = newFeePercentage;
        lastMerklClaimFeePercentageChangeTime = block.timestamp;

        emit MerklClaimFeePercentageUpdated(oldFee, newFeePercentage);
    }

    /**
     * @dev Update revenue address
     * @notice Only callable by admin (Gnosis Safe multisig)
     * @notice Requires 24-hour cooldown between changes
     * @param newRevenueAddress The new address to receive fees
     */
    function updateRevenueAddress(address newRevenueAddress) external onlyAdmin {
        require(newRevenueAddress != address(0), "Invalid revenue address");
        require(
            block.timestamp >= lastRevenueAddressChangeTime + FEE_CHANGE_TIMELOCK,
            "Revenue address change cooldown not passed (24 hours)"
        );

        address oldAddress = revenueAddress;
        revenueAddress = newRevenueAddress;
        lastRevenueAddressChangeTime = block.timestamp;

        emit RevenueAddressUpdated(oldAddress, newRevenueAddress);
    }

    // ============ View Functions ============

    /**
     * @dev Get the active vault for an asset
     */
    function getAssetActiveVault(address asset) external view returns (address) {
        return assetToVault[asset];
    }

    /**
     * @dev Check if a vault is available for a specific asset
     * @notice O(1) lookup using mapping
     */
    function isVaultAvailableForAsset(address asset, address vault) public view returns (bool) {
        return isAssetVaultAvailable[asset][vault];
    }
}
