const { ethers } = require("hardhat");
const { impersonateAccount, setBalance } = require("@nomicfoundation/hardhat-network-helpers");

/**
 * Standalone script to get USDC on a forked Base network
 * 
 * This script works when you start hardhat node separately with:
 *   npx hardhat node --fork https://mainnet.base.org
 * 
 * Then run this script with:
 *   npx hardhat run scripts/fork/getUSDC-standalone.js --network localhost
 */

// USDC token address on Base
const USDC_ADDRESS = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";

// Known USDC whales on Base
const USDC_WHALES = [
  "0x0e517979C2c1c1522ddB0c73905e0D39b3F990c0", // Coinbase Base account
  "0x4f3a120E72C76c22ae802D129F599BFDbc31cb81", // Large holder
  "0x4200000000000000000000000000000000000010", // Base system contract
  "0x6a5e9eCfcdD91bF9796bC6D2679D97A40f9f0082",
];

// Amount of USDC to transfer (in USDC units, 6 decimals)
const USDC_AMOUNT = ethers.parseUnits("10000", 6); // 10,000 USDC

async function main() {
  console.log("🚀 Getting USDC on forked Base network...\n");

  const network = await ethers.provider.getNetwork();
  console.log(`📡 Network: ${network.name} (Chain ID: ${network.chainId})\n`);

  const [signer] = await ethers.getSigners();
  console.log(`👤 Your account: ${signer.address}\n`);

  // Get USDC contract
  const usdc = await ethers.getContractAt(
    [
      "function balanceOf(address account) external view returns (uint256)",
      "function transfer(address to, uint256 amount) external returns (bool)",
      "function decimals() external view returns (uint8)",
    ],
    USDC_ADDRESS
  );

  // Check current balance
  const currentBalance = await usdc.balanceOf(signer.address);
  console.log(`💰 Current USDC balance: ${ethers.formatUnits(currentBalance, 6)} USDC\n`);

  // Find a whale
  let selectedWhale = null;
  let whaleBalance = 0n;
  
  console.log("🔍 Searching for a USDC whale...\n");
  
  for (const whale of USDC_WHALES) {
    try {
      const balance = await usdc.balanceOf(whale);
      console.log(`  Checking ${whale}: ${ethers.formatUnits(balance, 6)} USDC`);
      
      if (balance >= USDC_AMOUNT) {
        selectedWhale = whale;
        whaleBalance = balance;
        console.log(`  ✅ Found suitable whale!\n`);
        break;
      }
    } catch (error) {
      console.log(`  ❌ Error checking ${whale}: ${error.message}`);
      continue;
    }
  }

  if (!selectedWhale) {
    console.log("\n❌ No whale found with sufficient balance.");
    return;
  }

  // Impersonate and transfer
  console.log(`🎭 Impersonating whale: ${selectedWhale}\n`);
  await impersonateAccount(selectedWhale);
  await setBalance(selectedWhale, ethers.parseEther("100"));

  const whaleSigner = await ethers.getSigner(selectedWhale);

  console.log(`💸 Transferring ${ethers.formatUnits(USDC_AMOUNT, 6)} USDC...\n`);
  
  const tx = await usdc.connect(whaleSigner).transfer(signer.address, USDC_AMOUNT);
  await tx.wait();

  const newBalance = await usdc.balanceOf(signer.address);
  console.log(`✅ Transfer complete!\n`);
  console.log(`💰 New USDC balance: ${ethers.formatUnits(newBalance, 6)} USDC\n`);
  console.log("🎉 Success!\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


