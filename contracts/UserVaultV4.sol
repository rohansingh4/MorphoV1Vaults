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
}
