const { ethers } = require("hardhat");
const { impersonateAccount, setBalance } = require("@nomicfoundation/hardhat-network-helpers");

/**
 * Script to get USDC tokens on a forked Base network
 * 
 * Usage:
 *   FORKING=true npx hardhat run scripts/fork/getUSDC.js
 * 
 * This script:
 * 1. Impersonates a USDC whale on Base
 * 2. Transfers USDC to your account
 * 3. Shows the balance
 */

// USDC token address on Base
const USDC_ADDRESS = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";

// Known USDC whales on Base (large holders verified on BaseScan)
// Using getAddress() to ensure proper checksum
const USDC_WHALES = [
  ethers.getAddress("0x0e517979C2c1c1522ddB0c73905e0D39b3F990c0"), // Coinbase Base account
  ethers.getAddress("0x4f3a120E72C76c22ae802D129F599BFDbc31cb81"), // Large holder
  ethers.getAddress("0x4200000000000000000000000000000000000010"), // Base system contract
  ethers.getAddress("0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA"), // USDbC contract (legacy, but may work)
  ethers.getAddress("0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"), // USDC contract itself (try mint if available)
];

const USDC_WHALE = USDC_WHALES[0]; // Default to first whale

// Amount of USDC to transfer (in USDC units, 6 decimals)
// Start with smaller amount - can be adjusted
const USDC_AMOUNT = ethers.parseUnits("100", 6); // 100 USDC (start small, adjust as needed)

async function main() {
  console.log("🚀 Getting USDC on forked Base network...\n");

  // Check if forking is enabled
  const network = await ethers.provider.getNetwork();
  console.log(`📡 Network: ${network.name} (Chain ID: ${network.chainId})\n`);

  // Verify we're on the right chain
  if (network.chainId !== 8453n) {
    console.log("⚠️  Warning: Chain ID is not 8453 (Base). Make sure FORKING=true is set.\n");
  }

  // Get your signer (first account)
  const [signer] = await ethers.getSigners();
  console.log(`👤 Your account: ${signer.address}\n`);

  // Get USDC contract (using standard ERC20 ABI)
  const usdc = await ethers.getContractAt(
    [
      "function balanceOf(address account) external view returns (uint256)",
      "function transfer(address to, uint256 amount) external returns (bool)",
      "function decimals() external view returns (uint8)",
    ],
    USDC_ADDRESS
  );

  // Skip balance checking due to Hardhat v2 EDR hardfork issue
  // Reading balances triggers hardfork validation which fails for Base
  console.log("ℹ️  Skipping balance checks due to Hardhat v2 EDR limitation\n");
  console.log("ℹ️  Will try multiple whales if transfer fails\n\n");
  
  // Try each whale until one works
  let transferSuccessful = false;
  
  for (let i = 0; i < USDC_WHALES.length; i++) {
    const selectedWhale = USDC_WHALES[i];
    const whaleNames = [
      "Coinbase Base account", 
      "Large holder", 
      "Base system contract",
      "USDbC contract (legacy)",
      "USDC contract itself"
    ];
    
    console.log(`🎯 Trying whale ${i + 1}/${USDC_WHALES.length}: ${selectedWhale} (${whaleNames[i]})\n`);

    // Impersonate the whale
    await impersonateAccount(selectedWhale);
    await setBalance(selectedWhale, ethers.parseEther("100")); // Give some ETH for gas

    // Get impersonated signer
    const whaleSigner = await ethers.getSigner(selectedWhale);

    try {
      // Transfer USDC from whale to your account
      console.log(`💸 Transferring ${ethers.formatUnits(USDC_AMOUNT, 6)} USDC...\n`);
      
      const tx = await usdc.connect(whaleSigner).transfer(signer.address, USDC_AMOUNT);
      const receipt = await tx.wait();
      
      console.log(`✅ Transfer complete! Transaction hash: ${receipt.hash}\n`);
      transferSuccessful = true;
      
      // Try to check balance, but don't fail if it errors due to hardfork issue
      try {
        const newBalance = await usdc.balanceOf(signer.address);
        console.log(`💰 New USDC balance: ${ethers.formatUnits(newBalance, 6)} USDC\n`);
      } catch (error) {
        console.log(`⚠️  Could not verify balance (Hardhat v2 limitation), but transfer succeeded.\n`);
        console.log(`   You can verify in your tests/contracts by calling balanceOf(${signer.address})\n`);
      }

      console.log("🎉 Success! USDC has been transferred to your account.\n");
      break; // Exit loop on success
      
    } catch (error) {
      if (error.message.includes("transfer amount exceeds balance")) {
        console.log(`⚠️  This whale doesn't have enough USDC. Trying next...\n\n`);
        continue;
      } else {
        console.log(`❌ Error: ${error.message}\n`);
        throw error; // Re-throw unexpected errors
      }
    }
  }

  if (!transferSuccessful) {
    console.log("❌ Failed to transfer USDC from any whale.\n");
    console.log("💡 Suggestions:\n");
    console.log("   1. Reduce USDC_AMOUNT in the script (currently 1000 USDC)");
    console.log("   2. Use a different fork block: FORK_BLOCK_NUMBER=<block>");
    console.log("   3. Find a USDC whale manually: https://basescan.org/token/0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913#balances");
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

