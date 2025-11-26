const hre = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
  console.log("Starting test vault deployment via Factory...\n");

  const [deployer] = await ethers.getSigners();
  console.log("Deployer account:", deployer.address);
  console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH\n");

  // Get factory address from command line or latest deployment
  const factoryAddress = process.env.FACTORY_ADDRESS || process.argv[2];

  if (!factoryAddress) {
    console.error("❌ Error: Please provide factory address");
    console.log("Usage: npx hardhat run scripts/deploy/deployTestVault.js --network <network> <factory_address>");
    console.log("Or set FACTORY_ADDRESS environment variable");
    process.exit(1);
  }

  console.log("Using Factory at:", factoryAddress, "\n");

  // Get the factory contract
  const factory = await ethers.getContractAt("UserVaultFactory", factoryAddress);

  // Configuration (update these addresses for your target network)
  const vaultOwner = deployer.address;
  const vaultAdmin = process.env.VAULT_ADMIN || deployer.address;
  const revenueAddress = process.env.REVENUE_ADDRESS || deployer.address;

  // Token addresses (Base Mainnet)
  const USDC = process.env.USDC_ADDRESS || "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
  const WETH = process.env.WETH_ADDRESS || "0x4200000000000000000000000000000000000006";

  // Morpho Vault addresses - Update these with actual Morpho vaults
  const MORPHO_USDC_VAULT = process.env.MORPHO_USDC_VAULT || "0x0000000000000000000000000000000000000000";
  const MORPHO_WETH_VAULT = process.env.MORPHO_WETH_VAULT || "0x0000000000000000000000000000000000000000";

  // Assets configuration
  const assets = [USDC, WETH];
  const assetVaults = [MORPHO_USDC_VAULT, MORPHO_WETH_VAULT];
  const initialAllowedVaults = [MORPHO_USDC_VAULT, MORPHO_WETH_VAULT];

  // Fee configuration (in basis points)
  const feePercentage = process.env.FEE_PERCENTAGE || 100; // 1%
  const rebalanceFeePercentage = process.env.REBALANCE_FEE_PERCENTAGE || 1000; // 10%
  const merklClaimFeePercentage = process.env.MERKL_CLAIM_FEE_PERCENTAGE || 1000; // 10%

  // Generate unique salt
  const nonce = Date.now();

  console.log("=== Vault Configuration ===");
  console.log("Owner:", vaultOwner);
  console.log("Admin:", vaultAdmin);
  console.log("Revenue Address:", revenueAddress);
  console.log("Assets:", assets);
  console.log("Asset Vaults:", assetVaults);
  console.log("Fee Percentage:", feePercentage, "bps");
  console.log("Rebalance Fee:", rebalanceFeePercentage, "bps");
  console.log("Merkl Claim Fee:", merklClaimFeePercentage, "bps");
  console.log("Nonce:", nonce);
  console.log("============================\n");

  // Compute vault address
  const salt = await factory.generateDeterministicSalt(vaultOwner, nonce);
  console.log("Generated Salt:", salt);

  const predictedAddress = await factory.computeVaultAddress(
    vaultOwner,
    vaultAdmin,
    assets,
    assetVaults,
    initialAllowedVaults,
    revenueAddress,
    feePercentage,
    rebalanceFeePercentage,
    merklClaimFeePercentage,
    salt
  );

  console.log("Predicted Vault Address:", predictedAddress, "\n");

  // Get deployment fee
  const deploymentFee = await factory.deploymentFee();
  console.log("Required Deployment Fee:", ethers.formatEther(deploymentFee), "ETH");

  // Deploy vault
  console.log("Deploying vault...");
  const tx = await factory.deployVault(
    vaultOwner,
    vaultAdmin,
    assets,
    assetVaults,
    initialAllowedVaults,
    revenueAddress,
    feePercentage,
    rebalanceFeePercentage,
    merklClaimFeePercentage,
    salt,
    { value: deploymentFee }
  );

  console.log("Transaction hash:", tx.hash);
  console.log("Waiting for confirmation...");

  const receipt = await tx.wait();
  console.log("✅ Vault deployed successfully!");
  console.log("Gas used:", receipt.gasUsed.toString());
  console.log("");

  // Find the VaultDeployed event
  const event = receipt.logs.find(
    (log) => {
      try {
        const parsed = factory.interface.parseLog(log);
        return parsed.name === "VaultDeployed";
      } catch {
        return false;
      }
    }
  );

  if (event) {
    const parsed = factory.interface.parseLog(event);
    const vaultAddress = parsed.args[0];

    console.log("=== Deployment Summary ===");
    console.log("Vault Address:", vaultAddress);
    console.log("Owner:", parsed.args[1]);
    console.log("Admin:", parsed.args[2]);
    console.log("Salt:", parsed.args[3]);
    console.log("Chain ID:", parsed.args[4].toString());
    console.log("==========================\n");

    // Save deployment info
    const fs = require("fs");
    const network = await ethers.provider.getNetwork();

    const vaultInfo = {
      network: network.name,
      chainId: network.chainId.toString(),
      timestamp: new Date().toISOString(),
      factoryAddress: factoryAddress,
      vaultAddress: vaultAddress,
      owner: vaultOwner,
      admin: vaultAdmin,
      revenueAddress: revenueAddress,
      assets: assets,
      assetVaults: assetVaults,
      configuration: {
        feePercentage: feePercentage,
        rebalanceFeePercentage: rebalanceFeePercentage,
        merklClaimFeePercentage: merklClaimFeePercentage,
      },
      salt: salt,
      nonce: nonce,
      transactionHash: tx.hash,
    };

    const deploymentsDir = "./deployments/vaults";
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    const filename = `${deploymentsDir}/vault-${vaultAddress}-${Date.now()}.json`;
    fs.writeFileSync(filename, JSON.stringify(vaultInfo, null, 2));
    console.log("✅ Vault info saved to:", filename);

    return vaultAddress;
  } else {
    console.log("⚠️  Could not find VaultDeployed event");
  }
}

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = main;
