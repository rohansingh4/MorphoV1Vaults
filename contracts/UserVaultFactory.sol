// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./userVaultV4.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title UserVaultFactory
 * @dev Factory contract for deterministic cross-chain deployment of UserVault_V4 contracts using CREATE2
 * This ensures the same contract address across all supported chains for cross-chain Merkl reward claiming
 */
contract UserVaultFactory is Ownable, Pausable, ReentrancyGuard {

    // Events
    event VaultDeployed(
        address indexed vaultAddress,
        address indexed owner,
        address indexed admin,
        bytes32 salt,
        uint256 chainId
    );

    event VaultRegistered(
        address indexed vaultAddress,
        address indexed owner,
        uint256 indexed chainId
    );

    // Mapping to track deployed vaults by owner and salt
    mapping(address => mapping(bytes32 => address)) public deployedVaults;

    // Mapping to track all vaults by owner
    mapping(address => address[]) public ownerVaults;

    // Mapping to track if a vault is deployed by this factory
    mapping(address => bool) public isFactoryVault;

    // Registry of deployed vaults across chains (for tracking purposes)
    struct VaultInfo {
        address vaultAddress;
        address owner;
        address admin;
        uint256 chainId;
        bytes32 salt;
        uint256 deployedAt;
    }

    VaultInfo[] public vaultRegistry;
    mapping(address => uint256[]) public vaultsByOwner;

    // Factory configuration
    uint256 public deploymentFee; // Fee in wei to deploy a vault
    address public feeRecipient; // Address to receive deployment fees

    constructor(address _initialOwner, uint256 _deploymentFee, address _feeRecipient) Ownable(_initialOwner) {
        deploymentFee = _deploymentFee;
        feeRecipient = _feeRecipient != address(0) ? _feeRecipient : _initialOwner;
    }

    /**
     * @dev Compute the address where a vault would be deployed with given parameters
     * @param owner The owner of the vault
     * @param admin The admin of the vault
     * @param assets Array of initial assets (USDC, WETH, etc.)
     * @param assetVaults Array of initial vaults for each asset (must match assets length)
     * @param initialAllowedVaults Array of all vaults that are whitelisted
     * @param revenueAddress Address to receive fees
     * @param feePercentage Withdrawal fee percentage in basis points
     * @param rebalanceFeePercentage Rebalance fee percentage in basis points
     * @param merklClaimFeePercentage Merkl claim fee percentage in basis points
     * @param salt Unique salt for deterministic deployment
     * @return predictedAddress The predicted address of the vault
     */
    function computeVaultAddress(
        address owner,
        address admin,
        address[] memory assets,
        address[] memory assetVaults,
        address[] memory initialAllowedVaults,
        address revenueAddress,
        uint256 feePercentage,
        uint256 rebalanceFeePercentage,
        uint256 merklClaimFeePercentage,
        bytes32 salt
    ) public view returns (address predictedAddress) {
        bytes memory bytecode = abi.encodePacked(
            type(UserVault_V4).creationCode,
            abi.encode(
                owner,
                admin,
                assets,
                assetVaults,
                initialAllowedVaults,
                revenueAddress,
                feePercentage,
                rebalanceFeePercentage,
                merklClaimFeePercentage
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );

        return address(uint160(uint256(hash)));
    }

    /**
     * @dev Generate a deterministic salt based on user parameters
     * This ensures the same salt generates the same address across chains
     * @param owner The vault owner
     * @param nonce A unique nonce for the owner (to allow multiple vaults per owner)
     * @return Generated salt
     */
    function generateDeterministicSalt(
        address owner,
        uint256 nonce
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, nonce));
    }

    /**
     * @dev Deploy a new UserVault_V4 contract with deterministic address
     * @param owner The owner of the vault
     * @param admin The admin of the vault
     * @param assets Array of initial assets (USDC, WETH, WBTC, etc.)
     * @param assetVaults Array of initial vaults for each asset (must match assets length)
     * @param initialAllowedVaults Array of all vaults that are whitelisted
     * @param revenueAddress Address to receive fees
     * @param feePercentage Withdrawal fee percentage in basis points
     * @param rebalanceFeePercentage Rebalance fee percentage in basis points (e.g., 1000 = 10%)
     * @param merklClaimFeePercentage Merkl claim fee percentage in basis points (e.g., 1000 = 10%)
     * @param salt Unique salt for deterministic deployment
     * @return vaultAddress The deployed vault address
     */
    function deployVault(
        address owner,
        address admin,
        address[] memory assets,
        address[] memory assetVaults,
        address[] memory initialAllowedVaults,
        address revenueAddress,
        uint256 feePercentage,
        uint256 rebalanceFeePercentage,
        uint256 merklClaimFeePercentage,
        bytes32 salt
    ) external payable nonReentrant whenNotPaused returns (address vaultAddress) {

        // Check if deployment fee is required
        if (deploymentFee > 0) {
            require(msg.value >= deploymentFee, "Insufficient deployment fee");

            // Transfer fee to recipient
            (bool success, ) = feeRecipient.call{value: deploymentFee}("");
            require(success, "Fee transfer failed");

            // Refund excess
            if (msg.value > deploymentFee) {
                (bool refundSuccess, ) = msg.sender.call{value: msg.value - deploymentFee}("");
                require(refundSuccess, "Refund failed");
            }
        }

        // Check if vault already exists with this salt
        require(deployedVaults[owner][salt] == address(0), "Vault already exists with this salt");

        // Validate parameters
        require(owner != address(0), "Invalid owner");
        require(admin != address(0), "Invalid admin");
        require(assets.length > 0, "No initial assets");
        require(assets.length == assetVaults.length, "Assets and vaults length mismatch");
        require(initialAllowedVaults.length > 0, "No allowed vaults");
        require(revenueAddress != address(0), "Invalid revenue address");

        // Validate all assets and vaults are non-zero
        for (uint256 i = 0; i < assets.length; i++) {
            require(assets[i] != address(0), "Invalid asset address");
            require(assetVaults[i] != address(0), "Invalid vault address");
        }

        // Deploy the vault using CREATE2
        bytes memory bytecode = abi.encodePacked(
            type(UserVault_V4).creationCode,
            abi.encode(
                owner,
                admin,
                assets,
                assetVaults,
                initialAllowedVaults,
                revenueAddress,
                feePercentage,
                rebalanceFeePercentage,
                merklClaimFeePercentage
            )
        );

        assembly {
            vaultAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        require(vaultAddress != address(0), "Vault deployment failed");

        // Store deployment information
        deployedVaults[owner][salt] = vaultAddress;
        ownerVaults[owner].push(vaultAddress);
        isFactoryVault[vaultAddress] = true;

        // Add to registry
        vaultRegistry.push(VaultInfo({
            vaultAddress: vaultAddress,
            owner: owner,
            admin: admin,
            chainId: block.chainid,
            salt: salt,
            deployedAt: block.timestamp
        }));

        vaultsByOwner[owner].push(vaultRegistry.length - 1);

        emit VaultDeployed(vaultAddress, owner, admin, salt, block.chainid);

        return vaultAddress;
    }

    /**
     * @dev Deploy vault with auto-generated salt (convenience function)
     * @param owner The owner of the vault
     * @param admin The admin of the vault
     * @param assets Array of initial assets
     * @param assetVaults Array of initial vaults for each asset
     * @param initialAllowedVaults Array of all vaults that are whitelisted
     * @param revenueAddress Address to receive fees
     * @param feePercentage Withdrawal fee percentage in basis points
     * @param rebalanceFeePercentage Rebalance fee percentage in basis points
     * @param merklClaimFeePercentage Merkl claim fee percentage in basis points
     * @param nonce Unique nonce for the owner
     * @return vaultAddress The deployed vault address
     * @return salt The generated salt used for deployment
     */
    function deployVaultWithNonce(
        address owner,
        address admin,
        address[] memory assets,
        address[] memory assetVaults,
        address[] memory initialAllowedVaults,
        address revenueAddress,
        uint256 feePercentage,
        uint256 rebalanceFeePercentage,
        uint256 merklClaimFeePercentage,
        uint256 nonce
    ) external payable returns (address vaultAddress, bytes32 salt) {
        salt = generateDeterministicSalt(owner, nonce);

        vaultAddress = this.deployVault{value: msg.value}(
            owner,
            admin,
            assets,
            assetVaults,
            initialAllowedVaults,
            revenueAddress,
            feePercentage,
            rebalanceFeePercentage,
            merklClaimFeePercentage,
            salt
        );

        return (vaultAddress, salt);
    }

    /**
     * @dev Register an existing vault deployed on another chain (for tracking)
     * This is useful for keeping track of cross-chain deployments
     * @param vaultAddress The vault address on another chain
     * @param owner The vault owner
     * @param admin The vault admin
     * @param chainId The chain ID where the vault is deployed
     * @param salt The salt used for deployment
     */
    function registerCrossChainVault(
        address vaultAddress,
        address owner,
        address admin,
        uint256 chainId,
        bytes32 salt
    ) external onlyOwner {
        require(vaultAddress != address(0), "Invalid vault address");
        require(owner != address(0), "Invalid owner");
        require(chainId != block.chainid, "Use deployVault for current chain");

        vaultRegistry.push(VaultInfo({
            vaultAddress: vaultAddress,
            owner: owner,
            admin: admin,
            chainId: chainId,
            salt: salt,
            deployedAt: block.timestamp
        }));

        vaultsByOwner[owner].push(vaultRegistry.length - 1);

        emit VaultRegistered(vaultAddress, owner, chainId);
    }

    // View functions

    /**
     * @dev Get all vaults deployed by an owner
     */
    function getOwnerVaults(address owner) external view returns (address[] memory) {
        return ownerVaults[owner];
    }

    /**
     * @dev Get vault registry info by index
     */
    function getVaultInfo(uint256 index) external view returns (VaultInfo memory) {
        require(index < vaultRegistry.length, "Index out of bounds");
        return vaultRegistry[index];
    }

    /**
     * @dev Get total number of registered vaults
     */
    function getTotalVaults() external view returns (uint256) {
        return vaultRegistry.length;
    }

    /**
     * @dev Get vault registry indices for an owner
     */
    function getVaultIndicesByOwner(address owner) external view returns (uint256[] memory) {
        return vaultsByOwner[owner];
    }

    /**
     * @dev Check if a vault was deployed by this factory
     */
    function isVaultFromFactory(address vault) external view returns (bool) {
        return isFactoryVault[vault];
    }

    // Admin functions

    /**
     * @dev Update deployment fee (only owner)
     */
    function setDeploymentFee(uint256 newFee) external onlyOwner {
        deploymentFee = newFee;
    }

    /**
     * @dev Update fee recipient (only owner)
     */
    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Invalid recipient");
        feeRecipient = newRecipient;
    }

    /**
     * @dev Pause contract (only owner)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause contract (only owner)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Emergency withdraw ETH (only owner)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");

        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdrawal failed");
    }
}
