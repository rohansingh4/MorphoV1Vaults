// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./VaultMerkl.sol";

/**
 * @title VaultViews
 * @dev View functions and emergency operations
 */
abstract contract VaultViews is VaultMerkl {
    using SafeERC20 for IERC20;

    // ============ View Functions ============

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
     * @notice Optimized single-pass iteration; returns activeCount for array bounds
     * @return assets Array of asset addresses (use activeCount for valid entries)
     * @return deposited Array of deposited amounts
     * @return currentValues Array of current vault values
     * @return profits Array of profit/loss values
     * @return activeCount Number of valid entries in the arrays
     */
    function getPortfolioSummary()
        external
        view
        returns (
            address[] memory assets,
            uint256[] memory deposited,
            uint256[] memory currentValues,
            int256[] memory profits,
            uint256 activeCount
        )
    {
        uint256 totalAssets = allowedAssets.length;
        assets = new address[](totalAssets);
        deposited = new uint256[](totalAssets);
        currentValues = new uint256[](totalAssets);
        profits = new int256[](totalAssets);

        // Single-pass iteration
        for (uint256 i = 0; i < totalAssets; i++) {
            address asset = allowedAssets[i];
            if (assetHasInitialDeposit[asset]) {
                assets[activeCount] = asset;
                deposited[activeCount] = assetTotalDeposited[asset];
                currentValues[activeCount] = this.getAssetVaultAssets(asset);
                profits[activeCount] = this.getAssetProfit(asset);
                activeCount++;
            }
        }

        return (assets, deposited, currentValues, profits, activeCount);
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
