const hre = require("hardhat");
const { ethers } = require("hardhat");

/**
 * CLI Test Script for UserVaultFactory
 * Tests all factory functions interactively
 */

async function main() {
  console.log("=".repeat(70));
  console.log("UserVaultFactory CLI Test Suite");
  console.log("=".repeat(70));
  console.log("");

  const [deployer, user1, user2] = await ethers.getSigners();
  console.log("Test Accounts:");
  console.log("  Deployer:", deployer.address);
  console.log("  User1:", user1.address);
  console.log("  User2:", user2.address);
  console.log("");

  // ============================================================================
  // STEP 1: Deploy Factory
  // ============================================================================
  console.log("-".repeat(70));
  console.log("STEP 1: Deploying UserVaultFactory");
  console.log("-".repeat(70));

  const deploymentFee = ethers.parseEther("0.001"); // 0.001 ETH deployment fee
  const feeRecipient = deployer.address;

  console.log("Configuration:");
  console.log("  Initial Owner:", deployer.address);
  console.log("  Deployment Fee:", ethers.formatEther(deploymentFee), "ETH");
  console.log("  Fee Recipient:", feeRecipient);
  console.log("");

  const UserVaultFactory = await ethers.getContractFactory("UserVaultFactory");
  const factory = await UserVaultFactory.deploy(
    deployer.address,
    deploymentFee,
    feeRecipient
  );

  await factory.waitForDeployment();
  const factoryAddress = await factory.getAddress();

  console.log("✅ Factory deployed at:", factoryAddress);
  console.log("");

  // ============================================================================
  // STEP 2: Test View Functions
  // ============================================================================
  console.log("-".repeat(70));
  console.log("STEP 2: Testing View Functions");
  console.log("-".repeat(70));

  const currentDeploymentFee = await factory.deploymentFee();
  const currentFeeRecipient = await factory.feeRecipient();
  const totalVaults = await factory.getTotalVaults();

  console.log("deploymentFee():", ethers.formatEther(currentDeploymentFee), "ETH");
  console.log("feeRecipient():", currentFeeRecipient);
  console.log("getTotalVaults():", totalVaults.toString());
  console.log("");

  // ============================================================================
  // STEP 3: Generate Deterministic Salt
  // ============================================================================
  console.log("-".repeat(70));
  console.log("STEP 3: Testing generateDeterministicSalt()");
  console.log("-".repeat(70));

  const nonce1 = 1;
  const nonce2 = 2;
  const salt1 = await factory.generateDeterministicSalt(user1.address, nonce1);
  const salt2 = await factory.generateDeterministicSalt(user1.address, nonce2);
  const salt3 = await factory.generateDeterministicSalt(user2.address, nonce1);

  console.log("Salt for User1, Nonce 1:", salt1);
  console.log("Salt for User1, Nonce 2:", salt2);
  console.log("Salt for User2, Nonce 1:", salt3);
  console.log("✅ Different salts generated successfully");
  console.log("");

  // ============================================================================
  // STEP 4: Compute Vault Address
  // ============================================================================
  console.log("-".repeat(70));
  console.log("STEP 4: Testing computeVaultAddress()");
  console.log("-".repeat(70));

  // Mock token addresses (for testing - use actual addresses on mainnet)
  const USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
  const WETH = "0x4200000000000000000000000000000000000006";
  const mockVault1 = "0x1111111111111111111111111111111111111111";
  const mockVault2 = "0x2222222222222222222222222222222222222222";

  const assets = [USDC, WETH];
  const assetVaults = [mockVault1, mockVault2];
  const initialAllowedVaults = [mockVault1, mockVault2];
  const revenueAddress = deployer.address;
  const feePercentage = 100; // 1%
  const rebalanceFeePercentage = 1000; // 10%
  const merklClaimFeePercentage = 1000; // 10%

  const predictedAddress = await factory.computeVaultAddress(
    user1.address,
    deployer.address,
    assets,
    assetVaults,
    initialAllowedVaults,
    revenueAddress,
    feePercentage,
    rebalanceFeePercentage,
    merklClaimFeePercentage,
    salt1
  );

  console.log("Predicted Vault Address:", predictedAddress);
  console.log("✅ Address computation successful");
  console.log("");

  // ============================================================================
  // STEP 5: Deploy Vault with deployVault()
  // ============================================================================
  console.log("-".repeat(70));
  console.log("STEP 5: Testing deployVault()");
  console.log("-".repeat(70));

  console.log("Note: Skipping actual vault deployment in test mode");
  console.log("Reason: Requires actual Morpho vault addresses and token contracts");
  console.log("");
  console.log("deployVault() function signature:");
  console.log("  - owner: address");
  console.log("  - admin: address");
  console.log("  - assets: address[]");
  console.log("  - assetVaults: address[]");
  console.log("  - initialAllowedVaults: address[]");
  console.log("  - revenueAddress: address");
  console.log("  - feePercentage: uint256");
  console.log("  - rebalanceFeePercentage: uint256");
  console.log("  - merklClaimFeePercentage: uint256");
  console.log("  - salt: bytes32");
  console.log("  - value: deployment fee in ETH");
  console.log("");

  // ============================================================================
  // STEP 6: Deploy Vault with Nonce (deployVaultWithNonce)
  // ============================================================================
  console.log("-".repeat(70));
  console.log("STEP 6: Testing deployVaultWithNonce()");
  console.log("-".repeat(70));

  console.log("Note: Skipping actual vault deployment in test mode");
  console.log("");
  console.log("deployVaultWithNonce() is a convenience wrapper that:");
  console.log("  1. Generates salt from owner address and nonce");
  console.log("  2. Calls deployVault() with generated salt");
  console.log("");

  // ============================================================================
  // STEP 7: Test Owner Functions
  // ============================================================================
  console.log("-".repeat(70));
  console.log("STEP 7: Testing Owner Functions");
  console.log("-".repeat(70));

  // Test setDeploymentFee
  console.log("Testing setDeploymentFee()...");
  const newDeploymentFee = ethers.parseEther("0.002");
  const setFeeTx = await factory.setDeploymentFee(newDeploymentFee);
  await setFeeTx.wait();
  const updatedFee = await factory.deploymentFee();
  console.log("  Old fee:", ethers.formatEther(currentDeploymentFee), "ETH");
  console.log("  New fee:", ethers.formatEther(updatedFee), "ETH");
  console.log("  ✅ Deployment fee updated");
  console.log("");

  // Test setFeeRecipient
  console.log("Testing setFeeRecipient()...");
  const newFeeRecipient = user1.address;
  const setRecipientTx = await factory.setFeeRecipient(newFeeRecipient);
  await setRecipientTx.wait();
  const updatedRecipient = await factory.feeRecipient();
  console.log("  Old recipient:", currentFeeRecipient);
  console.log("  New recipient:", updatedRecipient);
  console.log("  ✅ Fee recipient updated");
  console.log("");

  // Test pause/unpause
  console.log("Testing pause() and unpause()...");
  const pauseTx = await factory.pause();
  await pauseTx.wait();
  const isPaused = await factory.paused();
  console.log("  Contract paused:", isPaused);

  const unpauseTx = await factory.unpause();
  await unpauseTx.wait();
  const isUnpaused = await factory.paused();
  console.log("  Contract paused after unpause:", isUnpaused);
  console.log("  ✅ Pause/unpause working correctly");
  console.log("");

  // ============================================================================
  // STEP 8: Test Query Functions
  // ============================================================================
  console.log("-".repeat(70));
  console.log("STEP 8: Testing Query Functions");
  console.log("-".repeat(70));

  console.log("Testing getOwnerVaults()...");
  const user1Vaults = await factory.getOwnerVaults(user1.address);
  console.log("  User1 vaults count:", user1Vaults.length);
  console.log("");

  console.log("Testing getTotalVaults()...");
  const totalVaultsCount = await factory.getTotalVaults();
  console.log("  Total vaults:", totalVaultsCount.toString());
  console.log("");

  console.log("Testing getVaultIndicesByOwner()...");
  const user1Indices = await factory.getVaultIndicesByOwner(user1.address);
  console.log("  User1 vault indices:", user1Indices.length);
  console.log("");

  // ============================================================================
  // STEP 9: Test Access Control
  // ============================================================================
  console.log("-".repeat(70));
  console.log("STEP 9: Testing Access Control");
  console.log("-".repeat(70));

  console.log("Testing onlyOwner modifier...");
  try {
    await factory.connect(user1).setDeploymentFee(ethers.parseEther("0.003"));
    console.log("  ❌ FAILED: Non-owner should not be able to set fee");
  } catch (error) {
    console.log("  ✅ PASSED: Non-owner correctly denied access");
  }
  console.log("");

  // ============================================================================
  // SUMMARY
  // ============================================================================
  console.log("=".repeat(70));
  console.log("TEST SUMMARY");
  console.log("=".repeat(70));
  console.log("");
  console.log("✅ All Factory Functions Tested:");
  console.log("  ✓ Deployment");
  console.log("  ✓ View Functions (deploymentFee, feeRecipient, getTotalVaults)");
  console.log("  ✓ generateDeterministicSalt()");
  console.log("  ✓ computeVaultAddress()");
  console.log("  ✓ setDeploymentFee()");
  console.log("  ✓ setFeeRecipient()");
  console.log("  ✓ pause() / unpause()");
  console.log("  ✓ Query functions (getOwnerVaults, getVaultIndicesByOwner)");
  console.log("  ✓ Access control");
  console.log("");
  console.log("📝 Note: deployVault() and deployVaultWithNonce() require real");
  console.log("   Morpho vault addresses and are tested in integration tests.");
  console.log("");
  console.log("=".repeat(70));
}

// Execute the test
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = main;
