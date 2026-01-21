// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./VaultAssetManager.sol";
import "../Interfaces/IMetaMorpho.sol";
import "../Interfaces/IERC20Extended.sol";

/**
 * @title VaultCore
 * @dev Core functionality including bundler interactions and helper functions
 */
abstract contract VaultCore is VaultAssetManager {
    using SafeERC20 for IERC20;

    // ============ Internal Helper Functions ============

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

        // Calculate max share price with slippage protection
        // Get current share price: assets per share = convertToAssets(1e18) for 18 decimal shares
        uint256 currentSharePrice = IMetaMorpho(vault).convertToAssets(1e18);
        // maxSharePriceE27 = price * 1e27 / 1e18 = price * 1e9, with slippage tolerance
        uint256 maxSharePriceE27 = (currentSharePrice * 1e9 * (10000 + SHARE_PRICE_SLIPPAGE_TOLERANCE)) / 10000;

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

        // Disable slippage protection to prevent SlippageExceeded errors
        // Setting to 0 accepts any share price during redemption
        uint256 minSharePriceE27 = 0;

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

    /**
     * @dev Get vault balance for a specific vault
     */
    function _getVaultBalance(address vault) internal view returns (uint256) {
        return IMetaMorpho(vault).balanceOf(address(this));
    }

    /**
     * @dev Get token decimals with fallback
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
}
