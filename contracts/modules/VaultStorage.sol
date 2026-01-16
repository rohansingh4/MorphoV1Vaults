// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../Interfaces/IBundler.sol";
import "../Interfaces/IMerklDistributor.sol";

/**
 * @title VaultStorage
 * @dev Base contract containing all state variables for the vault system
 */
abstract contract VaultStorage is ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    // ============ Constants ============

    // Bundler addresses
    address public constant ADAPTER_ADDRESS = 0xb98c948CFA24072e58935BC004a8A7b376AE746A;
    address public constant BUNDLER_ADDRESS = 0x6BFd8137e702540E7A42B74178A4a49Ba43920C4;

    // Merkl Distributor address
    address public constant MERKL_DISTRIBUTOR = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

    IBundler3 public constant bundler = IBundler3(BUNDLER_ADDRESS);
    IMerklDistributor public constant merklDistributor = IMerklDistributor(MERKL_DISTRIBUTOR);

    // Fee configuration
    uint256 public constant MAX_FEE_PERCENTAGE = 2000; // Maximum 20% fee in basis points
    uint256 public constant DEFAULT_FEE_PERCENTAGE = 1000; // Default 10% fee in basis points

    // Slippage protection for vault operations (in basis points, e.g., 100 = 1%)
    uint256 public constant SHARE_PRICE_SLIPPAGE_TOLERANCE = 100; // 1% slippage tolerance

    // ============ State Variables ============

    // Access control
    address public owner;
    address public admin;
    address public pendingOwner;

    // Multi-asset support: each asset has its own vault and tracking
    mapping(address => address) public assetToVault; // asset => current active vault for that asset
    mapping(address => address[]) public assetAvailableVaults; // asset => array of all allowed vaults for that asset
    mapping(address => uint256) public assetTotalDeposited; // asset => total deposited amount
    mapping(address => bool) public assetHasInitialDeposit; // asset => initial deposit status
    mapping(address => uint256) public assetLastDepositTime; // asset => last deposit timestamp
    mapping(address => uint256) public assetTotalFeesCollected; // asset => total fees collected

    // Asset-vault relationship tracking for O(1) lookups and removal
    mapping(address => mapping(address => bool)) internal isAssetVaultAvailable; // asset => vault => is available
    mapping(address => mapping(address => uint256)) internal assetVaultIndex; // asset => vault => index in assetAvailableVaults

    // Rebalance profit tracking: base amount from which profit is calculated during rebalance
    mapping(address => uint256) public assetRebalanceBaseAmount; // asset => base amount for profit calculation
    mapping(address => uint256) public assetTotalRebalanceFees; // asset => total rebalance fees collected

    // Allowed assets and vaults with index tracking for O(1) removal
    mapping(address => bool) public isAllowedAsset;
    mapping(address => bool) public isAllowedVault;
    mapping(address => uint256) internal assetIndex; // asset => index in allowedAssets array
    mapping(address => uint256) internal vaultIndex; // vault => index in allowedVaults array
    address[] public allowedAssets;
    address[] public allowedVaults;

    // Fee settings
    address public revenueAddress;
    uint256 public feePercentage = DEFAULT_FEE_PERCENTAGE; // Fee percentage in basis points (default 10%)
    uint256 public rebalanceFeePercentage = DEFAULT_FEE_PERCENTAGE; // Rebalance fee percentage in basis points (default 10%)
    uint256 public merklClaimFeePercentage = DEFAULT_FEE_PERCENTAGE; // Merkl claim fee percentage in basis points (default 10%)

    // Merkl operator approval status
    bool public adminApprovedForMerkl;

    // ============ Events ============

    event AssetAdded(address indexed asset, address indexed initialVault);
    event AssetRemoved(address indexed asset);
    event AssetVaultUpdated(address indexed asset, address indexed oldVault, address indexed newVault);
    event InitialDeposit(address indexed asset, address indexed vault, uint256 amount);
    event UserDeposit(address indexed asset, address indexed vault, uint256 amount);
    event Withdrawal(
        address indexed asset,
        address indexed vault,
        address indexed recipient,
        uint256 amount
    );
    event VaultAdded(address indexed vault);
    event VaultRemoved(address indexed vault);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event Rebalanced(
        address indexed asset,
        address indexed fromVault,
        address indexed toVault,
        uint256 amount
    );
    event RebalanceFeeCollected(
        address indexed asset,
        uint256 profitAmount,
        uint256 feeAmount,
        uint256 newBaseAmount
    );
    event RevenueAddressUpdated(
        address indexed oldAddress,
        address indexed newAddress
    );
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event RebalanceFeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event MerklClaimFeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event FeeCollected(
        address indexed asset,
        address indexed vault,
        uint256 feeAmount,
        uint256 userAmount
    );

    // Merkl events
    event MerklOperatorApproved(address indexed admin);
    event MerklTokensClaimed(address indexed token, uint256 totalAmount, uint256 feeAmount, uint256 userAmount);
    event MerklOperatorReapproved(address indexed admin);

    // Ownership events
    event OwnershipTransferInitiated(address indexed currentOwner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}
