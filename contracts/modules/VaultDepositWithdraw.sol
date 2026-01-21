// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./VaultCore.sol";

/**
 * @title VaultDepositWithdraw
 * @dev Handles all deposit and withdrawal operations
 */
abstract contract VaultDepositWithdraw is VaultCore {
    using SafeERC20 for IERC20;

    // ============ Deposit Functions ============

    /**
     * @dev Initial deposit for a specific asset
     * @notice Follows CEI (Checks-Effects-Interactions) pattern for reentrancy safety
     * @param asset The asset to deposit
     * @param vault The vault to deposit into (must be in assetAvailableVaults for this asset)
     * @param amount Amount to deposit
     */
    function initialDeposit(address asset, address vault, uint256 amount)
        external
        onlyOwner
        onlyAllowedAsset(asset)
        nonReentrant
    {
        // CHECKS
        require(!assetHasInitialDeposit[asset], "Initial deposit already made for this asset");
        require(amount > 0, "Amount must be positive");
        require(vault != address(0), "Invalid vault address");
        require(isVaultAvailableForAsset(asset, vault), "Vault not available for this asset");

        // EFFECTS - Update state before external calls
        assetToVault[asset] = vault;
        assetTotalDeposited[asset] = amount;
        assetHasInitialDeposit[asset] = true;
        assetLastDepositTime[asset] = block.timestamp;
        assetRebalanceBaseAmount[asset] = amount;

        // INTERACTIONS - External calls after state updates
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        _depositToVaultViaBundler(vault, amount, asset);

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
     * @notice Admin deposits affect the profit base amount
     * @param asset The asset to deposit
     * @param amount Amount to deposit
     */
    function adminDeposit(address asset, uint256 amount)
        external
        onlyAdmin
        onlyAllowedAsset(asset)
        nonReentrant
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
     * @notice Correctly tracks principal vs profit to prevent accounting issues
     * @param asset The asset to withdraw
     * @param amount Amount of shares to withdraw (0 for full withdrawal)
     */
    function withdraw(address asset, uint256 amount)
        external
        onlyOwner
        onlyAllowedAsset(asset)
        nonReentrant
    {
        require(assetHasInitialDeposit[asset], "No deposits for this asset");

        address vault = assetToVault[asset];
        uint256 vaultBalance = _getVaultBalance(vault);
        require(vaultBalance > 0, "No funds in vault");

        uint256 withdrawAmount = amount;
        if (amount == 0 || amount > vaultBalance) {
            withdrawAmount = vaultBalance; // Full withdrawal
        }

        // Calculate principal portion being withdrawn (proportional to shares)
        // This must be done BEFORE the redeem to get accurate share proportion
        uint256 principalPortion;
        if (withdrawAmount >= vaultBalance) {
            // Full withdrawal - all remaining principal
            principalPortion = assetTotalDeposited[asset];
        } else {
            // Partial withdrawal - proportional principal
            principalPortion = (assetTotalDeposited[asset] * withdrawAmount) / vaultBalance;
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

        // Update total deposited (reduce by principal portion only, not profit)
        if (principalPortion >= assetTotalDeposited[asset]) {
            assetTotalDeposited[asset] = 0;
        } else {
            assetTotalDeposited[asset] -= principalPortion;
        }

        emit Withdrawal(asset, vault, owner, userAmount);
    }
}
