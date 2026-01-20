// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./modules/VaultViews.sol";
import "./Interfaces/IMetaMorpho.sol";

/**
 * @title UserVault_V4
 * @dev Multi-asset individual user vault contract for yield optimization
 * @notice Modular architecture with separated concerns:
 *   - VaultStorage: State variables and events
 *   - VaultAccessControl: Access control and ownership
 *   - VaultAssetManager: Asset and vault management
 *   - VaultCore: Core bundler interactions and helpers
 *   - VaultDepositWithdraw: Deposit and withdrawal logic
 *   - VaultRebalance: Rebalancing operations
 *   - VaultMerkl: Merkl reward claiming
 *   - VaultViews: View functions and emergency operations
 */
contract UserVault_V4 is VaultViews {

    /**
     * @dev Constructor for multi-asset vault with multi-vault support per asset
     * @notice Admin and revenue address use default constants from VaultStorage
     * @param _owner The owner of the vault (must be EOA)
     * @param _assets Array of initial assets to support (e.g., [USDC, WETH, WBTC])
     * @param _assetVaults 2D array of vaults for each asset. Each asset can have multiple vaults.
     *        Example: [[USDC_Vault1, USDC_Vault2], [WETH_Vault1, WETH_Vault2, WETH_Vault3]]
     *        The first vault in each sub-array becomes the active/primary vault for that asset
     */
    constructor(
        address _owner,
        address[] memory _assets,
        address[][] memory _assetVaults
    ) {
        require(_owner != address(0), "Invalid owner");
        require(_owner.code.length == 0, "Owner must be EOA");
        require(_assets.length > 0, "No initial assets");
        require(_assets.length == _assetVaults.length, "Assets and vaults length mismatch");

        // Set owner (must be EOA)
        owner = _owner;

        // Use default admin and revenue addresses from constants
        admin = DEFAULT_ADMIN;
        revenueAddress = DEFAULT_REVENUE_ADDRESS;

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

                // Check for duplicate vaults for this asset (O(1) check)
                require(!isAssetVaultAvailable[_assets[i]][vault], "Duplicate vault for asset");

                // Add to asset's available vaults with O(1) tracking
                assetVaultIndex[_assets[i]][vault] = assetAvailableVaults[_assets[i]].length;
                isAssetVaultAvailable[_assets[i]][vault] = true;
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
}
