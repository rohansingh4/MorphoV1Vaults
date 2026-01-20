// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./VaultStorage.sol";

/**
 * @title VaultAccessControl
 * @dev Handles access control, modifiers, and ownership/admin management
 * @notice Supports Gnosis Safe multisig wallet for admin role with two-step transfers
 *
 * Role hierarchy:
 * - Owner: EOA user who owns the vault (can withdraw, claim rewards)
 * - Admin: Gnosis Safe multisig wallet for critical functions (fee changes, vault management, rebalancing)
 */
abstract contract VaultAccessControl is VaultStorage {

    // ============ Modifiers ============

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    /// @notice Restricts function access to admin (Gnosis Safe multisig)
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

    // ============ Admin Transfer (Two-Step for Gnosis Safe Compatibility) ============

    /**
     * @dev Initiate admin transfer (two-step process for Gnosis Safe compatibility)
     * @notice Only callable by current admin (Gnosis Safe multisig)
     * @notice The new admin must call acceptAdmin() to complete the transfer
     * @notice This allows Gnosis Safe multisig to safely transfer admin to another Safe
     * @param newAdmin The address to transfer admin role to (should be another Gnosis Safe)
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid new admin");
        require(newAdmin != admin, "Already the admin");
        pendingAdmin = newAdmin;
        emit AdminTransferInitiated(admin, newAdmin);
    }

    /**
     * @dev Accept admin transfer (must be called by pending admin)
     * @notice This is the second step of the two-step admin transfer
     */
    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "Not pending admin");
        address oldAdmin = admin;
        admin = pendingAdmin;
        pendingAdmin = address(0);
        emit AdminTransferCompleted(oldAdmin, admin);
    }

    /**
     * @dev Cancel pending admin transfer
     * @notice Only callable by current admin (Gnosis Safe multisig)
     */
    function cancelAdminTransfer() external onlyAdmin {
        require(pendingAdmin != address(0), "No pending transfer");
        address cancelled = pendingAdmin;
        pendingAdmin = address(0);
        emit AdminTransferCancelled(cancelled);
    }

    // ============ Ownership Transfer (Two-Step) ============

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
        address cancelled = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferCancelled(cancelled);
    }

}
