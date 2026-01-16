// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./VaultStorage.sol";

/**
 * @title VaultAccessControl
 * @dev Handles access control, modifiers, and ownership management
 */
abstract contract VaultAccessControl is VaultStorage {

    // ============ Modifiers ============

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

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

    // ============ Admin Management ============

    /**
     * @dev Update admin address
     */
    function updateAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid admin address");
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminUpdated(oldAdmin, newAdmin);
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
        pendingOwner = address(0);
    }

    // ============ Pause Functionality ============

    /**
     * @dev Pause the contract
     */
    function pause() external onlyAdmin {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyAdmin {
        _unpause();
    }
}
