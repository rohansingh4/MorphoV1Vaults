// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./VaultDepositWithdraw.sol";

/**
 * @title VaultRebalance
 * @dev Handles vault rebalancing operations with profit-based fee collection
 * @notice Rebalancing is restricted to admin (Gnosis Safe multisig wallet)
 */
abstract contract VaultRebalance is VaultDepositWithdraw {
    using SafeERC20 for IERC20;

    /**
     * @dev Rebalance a specific asset to a new vault (must be in available vaults for that asset)
     * @notice Only callable by admin (Gnosis Safe multisig)
     * @notice Requires 12-hour cooldown between rebalances for the same asset
     * @param asset The asset to rebalance
     * @param toVault The new vault to deposit into (must be in assetAvailableVaults)
     */
    function rebalanceToVault(address asset, address toVault)
        external
        onlyAdmin
        onlyAllowedAsset(asset)
        onlyAllowedVault(toVault)
        nonReentrant
    {
        require(assetHasInitialDeposit[asset], "No deposits for this asset");
        require(isVaultAvailableForAsset(asset, toVault), "Vault not available for this asset");
        require(
            block.timestamp >= assetLastRebalanceTime[asset] + REBALANCE_COOLDOWN,
            "Rebalance cooldown not passed (12 hours)"
        );

        address fromVault = assetToVault[asset];
        require(fromVault != toVault, "Same vault");
        require(IMetaMorpho(toVault).asset() == asset, "Vault asset mismatch");

        uint256 balance = _getVaultBalance(fromVault);
        require(balance > 0, "No funds to rebalance");

        // Redeem from current vault
        uint256 redeemedAmount = _redeemFromVaultViaBundler(fromVault, balance);

        // Calculate profit and deduct rebalance fee if there's profit
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

        // Update last rebalance time for cooldown enforcement
        assetLastRebalanceTime[asset] = block.timestamp;

        emit Rebalanced(asset, fromVault, toVault, amountToDeposit);
    }
}
