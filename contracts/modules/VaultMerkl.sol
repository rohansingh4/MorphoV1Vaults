// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./VaultRebalance.sol";

/**
 * @title VaultMerkl
 * @dev Handles Merkl reward claiming and distribution
 * @notice Only owner can claim rewards - admin claim functions removed for security
 */
abstract contract VaultMerkl is VaultRebalance {
    using SafeERC20 for IERC20;

    /**
     * @dev Claim single Merkl reward token
     * @notice Only owner can claim rewards
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
     * @notice Only owner can claim rewards
     * @notice Batch size limited to MAX_MERKL_BATCH_SIZE to bound gas costs
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
        require(tokens.length <= MAX_MERKL_BATCH_SIZE, "Batch size exceeds maximum");

        // Prepare arrays for batch claim
        address[] memory accounts = new address[](tokens.length);

        // Track balances before and check for duplicates
        uint256[] memory balancesBefore = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokens[i] != address(0), "Invalid token address");
            require(claimables[i] > 0, "Nothing to claim");

            // Check for duplicate tokens in batch
            for (uint256 j = 0; j < i; j++) {
                require(tokens[i] != tokens[j], "Duplicate token in batch");
            }

            balancesBefore[i] = IERC20(tokens[i]).balanceOf(address(this));
            accounts[i] = address(this);
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

}
