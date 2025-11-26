const hre = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
  console.log("Starting deployment...\n");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH\n");

  // Get network
  const network = await ethers.provider.getNetwork();
  console.log("Network:", network.name);
  console.log("Chain ID:", network.chainId.toString(), "\n");

  // Deployment Configuration
  const deploymentFee = process.env.DEPLOYMENT_FEE || "0";
  const feeRecipient = process.env.FEE_RECIPIENT || deployer.address;

  console.log("=== Deployment Configuration ===");
  console.log("Initial Owner:", deployer.address);
  console.log("Deployment Fee:", ethers.formatEther(deploymentFee), "ETH");
  console.log("Fee Recipient:", feeRecipient);
  console.log("================================\n");

  // Deploy UserVaultFactory
  console.log("Deploying UserVaultFactory...");
  const UserVaultFactory = await ethers.getContractFactory("UserVaultFactory");
  const factory = await UserVaultFactory.deploy(
    deployer.address,  // initialOwner
    deploymentFee,     // deploymentFee
    feeRecipient       // feeRecipient
  );

  await factory.waitForDeployment();
  const factoryAddress = await factory.getAddress();

  console.log("✅ UserVaultFactory deployed to:", factoryAddress);
  console.log("");

  // Get deployment transaction hash
  const deploymentTx = factory.deploymentTransaction();
  console.log("Deployment transaction hash:", deploymentTx.hash);
  console.log("");

  // Display deployment summary
  console.log("=== Deployment Summary ===");
  console.log("UserVaultFactory:", factoryAddress);
  console.log("Deployment Fee:", ethers.formatEther(deploymentFee), "ETH");
  console.log("Fee Recipient:", feeRecipient);
  console.log("==========================\n");

  // Save deployment addresses
  const fs = require("fs");
  const deploymentInfo = {
    network: network.name,
    chainId: network.chainId.toString(),
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      UserVaultFactory: factoryAddress,
    },
    configuration: {
      deploymentFee: deploymentFee,
      feeRecipient: feeRecipient,
    },
  };

  const deploymentsDir = "./deployments";
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir);
  }

  const filename = `${deploymentsDir}/${network.name}-${Date.now()}.json`;
  fs.writeFileSync(filename, JSON.stringify(deploymentInfo, null, 2));
  console.log("✅ Deployment info saved to:", filename);

  // Verification instructions
  if (network.chainId !== 31337n) {
    console.log("\n=== Verification Instructions ===");
    console.log("To verify the contract on Basescan, run:");
    console.log(
      `npx hardhat verify --network ${network.name} ${factoryAddress} "${deployer.address}" "${deploymentFee}" "${feeRecipient}"`
    );
    console.log("=================================\n");
  }

  return {
    factory: factoryAddress,
  };
}

// Execute deployment
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = main;
