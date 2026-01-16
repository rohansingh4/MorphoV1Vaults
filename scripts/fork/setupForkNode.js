/**
 * Setup script that runs after forked node starts
 * Seeds USDC to default Hardhat accounts
 * 
 * Run this after starting the forked node:
 *   FORKING=true npx hardhat run scripts/fork/setupForkNode.js
 */

const { ethers } = require("hardhat");
const { impersonateAccount, setBalance } = require("@nomicfoundation/hardhat-network-helpers");

const USDC_ADDRESS = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
const USDC_WHALE = ethers.getAddress("0x4200000000000000000000000000000000000010");
const USDC_AMOUNT = ethers.parseUnits("10000", 6); // 10,000 USDC per account

async function main() {
  console.log("🌱 Setting up forked node - seeding USDC...\n");

  const accounts = await ethers.getSigners();
  const accountsToFund = accounts.slice(0, 5);

  const usdc = await ethers.getContractAt(
    ["function transfer(address to, uint256 amount) external returns (bool)"],
    USDC_ADDRESS
  );

  await impersonateAccount(USDC_WHALE);
  await setBalance(USDC_WHALE, ethers.parseEther("100"));
  const whaleSigner = await ethers.getSigner(USDC_WHALE);

  console.log(`💰 Funding ${accountsToFund.length} accounts with ${ethers.formatUnits(USDC_AMOUNT, 6)} USDC each...\n`);

  for (let i = 0; i < accountsToFund.length; i++) {
    const account = accountsToFund[i];
    try {
      const tx = await usdc.connect(whaleSigner).transfer(account.address, USDC_AMOUNT);
      await tx.wait();
      console.log(`✅ Account ${i + 1}: ${account.address}`);
    } catch (error) {
      console.log(`⚠️  Account ${i + 1}: ${account.address} - ${error.message}`);
    }
  }

  console.log("\n✨ Setup complete! Accounts ready for Remix IDE.\n");
  console.log("📝 Account addresses:");
  accountsToFund.forEach((acc, i) => {
    console.log(`   ${i + 1}. ${acc.address}`);
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error:", error.message);
    process.exit(1);
  });

