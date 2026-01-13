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
     * @param owner The owner of the vault
     * @param admin The admin of the vault
     * @param assets Array of initial assets (USDC, WETH, etc.)
     * @param assetVaults 2D array of vaults for each asset (each asset can have multiple vaults)
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
        address[][] memory assetVaults,
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
     * @param assetVaults 2D array of vaults for each asset. Each asset can have multiple vaults.
     *        Example: [[USDC_Vault1, USDC_Vault2, USDC_Vault3], [WETH_Vault1, WETH_Vault2]]
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
        address[][] memory assetVaults,
        address revenueAddress,
        uint256 feePercentage,
        uint256 rebalanceFeePercentage,
        uint256 merklClaimFeePercentage,
        bytes32 salt
    ) external nonReentrant whenNotPaused returns (address vaultAddress) {

        require(deployedVaults[owner][salt] == address(0), "Exists");
        require(owner != address(0), "Owner 0");
        require(admin != address(0), "Admin 0");
        require(assets.length > 0, "No assets");
        require(assets.length == assetVaults.length, "Length");
        require(revenueAddress != address(0), "Revenue 0");

        for (uint256 i = 0; i < assets.length; i++) {
            require(assets[i] != address(0), "Asset 0");
            require(assetVaults[i].length > 0, "Vault cnt");
            for (uint256 j = 0; j < assetVaults[i].length; j++) {
                require(assetVaults[i][j] != address(0), "Vault 0");
            }
        }

        // Deploy the vault using CREATE2
        bytes memory bytecode = abi.encodePacked(
            type(UserVault_V4).creationCode,
            abi.encode(
                owner,
                admin,
                assets,
                assetVaults,
                revenueAddress,
                feePercentage,
                rebalanceFeePercentage,
                merklClaimFeePercentage
            )
        );

        assembly {
            vaultAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        require(vaultAddress != address(0), "Deploy fail");

        // Store deployment information
        deployedVaults[owner][salt] = vaultAddress;
        ownerVaults[owner].push(vaultAddress);
        isFactoryVault[vaultAddress] = true;

        emit VaultDeployed(vaultAddress, owner, admin, salt, block.chainid);

        return vaultAddress;
    }

    /**
     * @dev Deploy vault with auto-generated salt (convenience function)
     * @param owner The owner of the vault
     * @param admin The admin of the vault
     * @param assets Array of initial assets
     * @param assetVaults 2D array of vaults for each asset
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
        address[][] memory assetVaults,
        address revenueAddress,
        uint256 feePercentage,
        uint256 rebalanceFeePercentage,
        uint256 merklClaimFeePercentage,
        uint256 nonce
    ) external returns (address vaultAddress, bytes32 salt) {
        salt = generateDeterministicSalt(owner, nonce);

        vaultAddress = this.deployVault(
            owner,
            admin,
            assets,
            assetVaults,
            revenueAddress,
            feePercentage,
            rebalanceFeePercentage,
            merklClaimFeePercentage,
            salt
        );

        return (vaultAddress, salt);
    }

    // View functions

    /**
     * @dev Get all vaults deployed by an owner
     */
    function getOwnerVaults(address owner) external view returns (address[] memory) {
        return ownerVaults[owner];
    }

    /**
     * @dev Check if a vault was deployed by this factory
     */
    function isVaultFromFactory(address vault) external view returns (bool) {
        return isFactoryVault[vault];
    }

    // Admin functions

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