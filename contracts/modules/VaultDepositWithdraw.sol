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
}
