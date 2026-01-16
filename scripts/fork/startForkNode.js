const { ethers } = require("hardhat");
const { impersonateAccount, setBalance } = require("@nomicfoundation/hardhat-network-helpers");

/**
 * Script to seed USDC to Hardhat default accounts on fork startup
 * This runs automatically when starting the forked node
 */

const USDC_ADDRESS = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
const USDC_WHALE = ethers.getAddress("0x4200000000000000000000000000000000000010"); // Base system contract
const USDC_AMOUNT = ethers.parseUnits("10000", 6); // 10,000 USDC per account

async function main() {
  console.log("🌱 Seeding USDC to Hardhat accounts on fork...\n");

  const network = await ethers.provider.getNetwork();
  console.log(`📡 Network: ${network.name} (Chain ID: ${network.chainId})\n`);

  // Get first 5 Hardhat accounts
  const accounts = await ethers.getSigners();
  const accountsToFund = accounts.slice(0, 5);

  // Get USDC contract
  const usdc = await ethers.getContractAt(
    [
      "function transfer(address to, uint256 amount) external returns (bool)",
    ],
    USDC_ADDRESS
  );

  // Impersonate whale
  console.log(`🎭 Impersonating whale: ${USDC_WHALE}\n`);
  await impersonateAccount(USDC_WHALE);
  await setBalance(USDC_WHALE, ethers.parseEther("100"));
  const whaleSigner = await ethers.getSigner(USDC_WHALE);

  // Transfer USDC to each account
  for (let i = 0; i < accountsToFund.length; i++) {
    const account = accountsToFund[i];
    try {
      const tx = await usdc.connect(whaleSigner).transfer(account.address, USDC_AMOUNT);
      await tx.wait();
      console.log(`✅ Account ${i + 1}: ${account.address} - ${ethers.formatUnits(USDC_AMOUNT, 6)} USDC`);
    } catch (error) {
      console.log(`⚠️  Account ${i + 1}: ${account.address} - Failed: ${error.message}`);
    }
  }

  console.log("\n🎉 Seeding complete! Accounts are ready for testing.\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error:", error.message);
    process.exit(1);
  });

