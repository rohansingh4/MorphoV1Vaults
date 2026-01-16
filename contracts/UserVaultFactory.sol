// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./UserVaultV4.sol";
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

    // Mapping to track deployed vaults by owner and salt
    mapping(address => mapping(bytes32 => address)) public deployedVaults;

    // Mapping to track all vaults by owner
    mapping(address => address[]) public ownerVaults;

    // Mapping to track if a vault is deployed by this factory
    mapping(address => bool) public isFactoryVault;

    constructor(address _initialOwner) Ownable(_initialOwner) {
    }

    /**
     * @dev Compute the address where a vault would be deployed with given parameters
     * @param vaultOwner The owner of the vault
     * @param admin The admin of the vault
     * = 
     * @param assets Array of initial assets (USDC, WETH, etc.)
     * @param assetVaults 2D array of vaults for each asset (each asset can have multiple vaults)
     * @param revenueAddress Address to receive fees
     * @param salt Unique salt for deterministic deployment
     * @return predictedAddress The predicted address of the vault
     */
    function computeVaultAddress(
        address vaultOwner,
        address admin,
        address[] memory assets,
        address[][] memory assetVaults,
        address revenueAddress,
        bytes32 salt
    ) public view returns (address predictedAddress) {
        bytes memory bytecode = abi.encodePacked(
            type(UserVault_V4).creationCode,
            abi.encode(
                vaultOwner,
                admin,
                assets,
                assetVaults,
                revenueAddress
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
     * @param vaultOwner The vault owner
     * @param nonce A unique nonce for the owner (to allow multiple vaults per owner)
     * @return Generated salt
     */
    function generateDeterministicSalt(
        address vaultOwner,
        uint256 nonce
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(vaultOwner, nonce));
    }

    /**
     * @dev Deploy a new UserVault_V4 contract with deterministic address
     * @param vaultOwner The owner of the vault
     * @param admin The admin of the vault
     * @param assets Array of initial assets (USDC, WETH, WBTC, etc.)
     * @param assetVaults 2D array of vaults for each asset. Each asset can have multiple vaults.
     *        Example: [[USDC_Vault1, USDC_Vault2, USDC_Vault3], [WETH_Vault1, WETH_Vault2]]
     * @param revenueAddress Address to receive fees
     * @param salt Unique salt for deterministic deployment
     * @return vaultAddress The deployed vault address
     */
    function deployVault(
        address vaultOwner,
        address admin,
        address[] memory assets,
        address[][] memory assetVaults,
        address revenueAddress,
        bytes32 salt
    ) external nonReentrant whenNotPaused returns (address vaultAddress) {

        require(deployedVaults[vaultOwner][salt] == address(0), "Vault already exists for this owner and salt");
        require(vaultOwner != address(0), "Invalid owner address");
        require(admin != address(0), "Invalid admin address");
        require(assets.length > 0, "No assets provided");
        require(assets.length == assetVaults.length, "Assets and vaults array length mismatch");
        require(revenueAddress != address(0), "Invalid revenue address");

        for (uint256 i = 0; i < assets.length; i++) {
            require(assets[i] != address(0), "Invalid asset address");
            require(assetVaults[i].length > 0, "Each asset must have at least one vault");
            for (uint256 j = 0; j < assetVaults[i].length; j++) {
                require(assetVaults[i][j] != address(0), "Invalid vault address");
            }
        }

        // Deploy the vault using CREATE2
        bytes memory bytecode = abi.encodePacked(
            type(UserVault_V4).creationCode,
            abi.encode(
                vaultOwner,
                admin,
                assets,
                assetVaults,
                revenueAddress
            )
        );

        assembly {
            vaultAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        require(vaultAddress != address(0), "Vault deployment failed");

        // Store deployment information
        deployedVaults[vaultOwner][salt] = vaultAddress;
        ownerVaults[vaultOwner].push(vaultAddress);
        isFactoryVault[vaultAddress] = true;

        emit VaultDeployed(vaultAddress, vaultOwner, admin, salt, block.chainid);

        return vaultAddress;
    }

    /**
     * @dev Deploy vault with auto-generated salt (convenience function)
     * @param vaultOwner The owner of the vault
     * @param admin The admin of the vault
     * @param assets Array of initial assets
     * @param assetVaults 2D array of vaults for each asset
     * @param revenueAddress Address to receive fees
     * @param nonce Unique nonce for the owner
     * @return vaultAddress The deployed vault address
     * @return salt The generated salt used for deployment
     */
    function deployVaultWithNonce(
        address vaultOwner,
        address admin,
        address[] memory assets,
        address[][] memory assetVaults,
        address revenueAddress,
        uint256 nonce
    ) external returns (address vaultAddress, bytes32 salt) {
        salt = generateDeterministicSalt(vaultOwner, nonce);

        vaultAddress = this.deployVault(
            vaultOwner,
            admin,
            assets,
            assetVaults,
            revenueAddress,
            salt
        );

        return (vaultAddress, salt);
    }

    // ============ View Functions ============

    /**
     * @dev Get all vaults deployed by an owner
     */
    function getOwnerVaults(address vaultOwner) external view returns (address[] memory) {
        return ownerVaults[vaultOwner];
    }

    /**
     * @dev Get the number of vaults deployed by an owner
     */
    function getOwnerVaultCount(address vaultOwner) external view returns (uint256) {
        return ownerVaults[vaultOwner].length;
    }

    /**
     * @dev Check if a vault was deployed by this factory
     */
    function isVaultFromFactory(address vault) external view returns (bool) {
        return isFactoryVault[vault];
    }

    /**
     * @dev Get vault address by owner and salt
     */
    function getVaultByOwnerAndSalt(address vaultOwner, bytes32 salt) external view returns (address) {
        return deployedVaults[vaultOwner][salt];
    }

    // ============ Admin Functions ============

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
}
