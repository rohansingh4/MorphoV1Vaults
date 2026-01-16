const { ethers } = require("hardhat");

/**
 * Test script to verify forking is working
 * Run with: FORKING=true npx hardhat run scripts/fork/test-fork.js
 */

async function main() {
  console.log("🔍 Testing Base fork connection...\n");

  const network = await ethers.provider.getNetwork();
  console.log(`📡 Network: ${network.name}`);
  console.log(`🔗 Chain ID: ${network.chainId}\n`);

  // Try to get a block
  try {
    const block = await ethers.provider.getBlockNumber();
    console.log(`✅ Connected! Current block: ${block}\n`);
  } catch (error) {
    console.log(`❌ Failed to get block: ${error.message}\n`);
    return;
  }

  // Try to read USDC contract
  const USDC_ADDRESS = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
  try {
    const code = await ethers.provider.getCode(USDC_ADDRESS);
    if (code === "0x") {
      console.log(`⚠️  USDC contract not found at ${USDC_ADDRESS}`);
      console.log(`   This might mean you're forking from a block before USDC was deployed.\n`);
    } else {
      console.log(`✅ USDC contract found at ${USDC_ADDRESS}\n`);
    }
  } catch (error) {
    console.log(`❌ Error checking USDC: ${error.message}\n`);
  }

  // Try to get balance of a known whale
  const WHALE = "0x0e517979C2c1c1522ddB0c73905e0D39b3F990c0";
  try {
    const usdc = await ethers.getContractAt(
      ["function balanceOf(address) view returns (uint256)"],
      USDC_ADDRESS
    );
    const balance = await usdc.balanceOf(WHALE);
    console.log(`💰 Whale ${WHALE} balance: ${ethers.formatUnits(balance, 6)} USDC\n`);
  } catch (error) {
    console.log(`⚠️  Could not check whale balance: ${error.message}\n`);
  }

  console.log("✨ Fork test complete!\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error:", error.message);
    process.exit(1);
  });


