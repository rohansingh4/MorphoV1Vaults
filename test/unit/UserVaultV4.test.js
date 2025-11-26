const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("UserVault_V4", function () {
  // Note: These tests are limited because UserVault_V4 requires actual
  // Morpho vault addresses and token contracts to function properly.
  // Integration tests with forked mainnet would be more appropriate.

  describe("Constructor Validation", function () {
    it("Should revert with invalid owner", async function () {
      const [, admin, revenueAddr] = await ethers.getSigners();

      const mockAsset = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
      const mockVault = "0x1111111111111111111111111111111111111111";

      const UserVault = await ethers.getContractFactory("UserVault_V4");

      await expect(
        UserVault.deploy(
          ethers.ZeroAddress, // invalid owner
          admin.address,
          [mockAsset],
          [mockVault],
          [mockVault],
          revenueAddr.address,
          100,
          1000,
          1000
        )
      ).to.be.revertedWith("Invalid owner");
    });

    it("Should revert with invalid admin", async function () {
      const [owner, , revenueAddr] = await ethers.getSigners();

      const mockAsset = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
      const mockVault = "0x1111111111111111111111111111111111111111";

      const UserVault = await ethers.getContractFactory("UserVault_V4");

      await expect(
        UserVault.deploy(
          owner.address,
          ethers.ZeroAddress, // invalid admin
          [mockAsset],
          [mockVault],
          [mockVault],
          revenueAddr.address,
          100,
          1000,
          1000
        )
      ).to.be.revertedWith("Invalid admin");
    });

    it("Should revert with no initial assets", async function () {
      const [owner, admin, revenueAddr] = await ethers.getSigners();

      const mockVault = "0x1111111111111111111111111111111111111111";

      const UserVault = await ethers.getContractFactory("UserVault_V4");

      await expect(
        UserVault.deploy(
          owner.address,
          admin.address,
          [], // no assets
          [],
          [mockVault],
          revenueAddr.address,
          100,
          1000,
          1000
        )
      ).to.be.revertedWith("No initial assets");
    });

    it("Should revert with assets/vaults length mismatch", async function () {
      const [owner, admin, revenueAddr] = await ethers.getSigners();

      const mockAsset = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
      const mockVault1 = "0x1111111111111111111111111111111111111111";
      const mockVault2 = "0x2222222222222222222222222222222222222222";

      const UserVault = await ethers.getContractFactory("UserVault_V4");

      await expect(
        UserVault.deploy(
          owner.address,
          admin.address,
          [mockAsset],
          [mockVault1, mockVault2], // length mismatch
          [mockVault1, mockVault2],
          revenueAddr.address,
          100,
          1000,
          1000
        )
      ).to.be.revertedWith("Assets and vaults length mismatch");
    });

    it("Should revert with invalid revenue address", async function () {
      const [owner, admin] = await ethers.getSigners();

      const mockAsset = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
      const mockVault = "0x1111111111111111111111111111111111111111";

      const UserVault = await ethers.getContractFactory("UserVault_V4");

      await expect(
        UserVault.deploy(
          owner.address,
          admin.address,
          [mockAsset],
          [mockVault],
          [mockVault],
          ethers.ZeroAddress, // invalid revenue address
          100,
          1000,
          1000
        )
      ).to.be.revertedWith("Invalid revenue address");
    });

    it("Should revert with invalid asset address", async function () {
      const [owner, admin, revenueAddr] = await ethers.getSigners();

      const mockVault = "0x1111111111111111111111111111111111111111";

      const UserVault = await ethers.getContractFactory("UserVault_V4");

      await expect(
        UserVault.deploy(
          owner.address,
          admin.address,
          [ethers.ZeroAddress], // invalid asset
          [mockVault],
          [mockVault],
          revenueAddr.address,
          100,
          1000,
          1000
        )
      ).to.be.revertedWith("Invalid asset address");
    });

    it("Should revert with invalid vault address", async function () {
      const [owner, admin, revenueAddr] = await ethers.getSigners();

      const mockAsset = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";

      const UserVault = await ethers.getContractFactory("UserVault_V4");

      await expect(
        UserVault.deploy(
          owner.address,
          admin.address,
          [mockAsset],
          [ethers.ZeroAddress], // invalid vault
          [ethers.ZeroAddress],
          revenueAddr.address,
          100,
          1000,
          1000
        )
      ).to.be.revertedWith("Invalid vault address");
    });
  });

  describe("Constants", function () {
    it("Should have correct Aerodrome addresses", async function () {
      const [owner, admin, revenueAddr] = await ethers.getSigners();

      const mockAsset = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
      const mockVault = "0x1111111111111111111111111111111111111111";

      const UserVault = await ethers.getContractFactory("UserVault_V4");
      const vault = await UserVault.deploy(
        owner.address,
        admin.address,
        [mockAsset],
        [mockVault],
        [mockVault],
        revenueAddr.address,
        100,
        1000,
        1000
      );

      await vault.waitForDeployment();

      expect(await vault.AERODROME_ROUTER()).to.equal(
        "0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43"
      );
      expect(await vault.AERODROME_FACTORY()).to.equal(
        "0x420DD381b31aEf6683db6B902084cB0FFECe40Da"
      );
    });

    it("Should have correct Bundler addresses", async function () {
      const [owner, admin, revenueAddr] = await ethers.getSigners();

      const mockAsset = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
      const mockVault = "0x1111111111111111111111111111111111111111";

      const UserVault = await ethers.getContractFactory("UserVault_V4");
      const vault = await UserVault.deploy(
        owner.address,
        admin.address,
        [mockAsset],
        [mockVault],
        [mockVault],
        revenueAddr.address,
        100,
        1000,
        1000
      );

      await vault.waitForDeployment();

      expect(await vault.ADAPTER_ADDRESS()).to.equal(
        "0xb98c948CFA24072e58935BC004a8A7b376AE746A"
      );
      expect(await vault.BUNDLER_ADDRESS()).to.equal(
        "0x6BFd8137e702540E7A42B74178A4a49Ba43920C4"
      );
    });

    it("Should have correct Merkl distributor address", async function () {
      const [owner, admin, revenueAddr] = await ethers.getSigners();

      const mockAsset = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
      const mockVault = "0x1111111111111111111111111111111111111111";

      const UserVault = await ethers.getContractFactory("UserVault_V4");
      const vault = await UserVault.deploy(
        owner.address,
        admin.address,
        [mockAsset],
        [mockVault],
        [mockVault],
        revenueAddr.address,
        100,
        1000,
        1000
      );

      await vault.waitForDeployment();

      expect(await vault.MERKL_DISTRIBUTOR()).to.equal(
        "0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae"
      );
    });

    it("Should have correct slippage tolerance", async function () {
      const [owner, admin, revenueAddr] = await ethers.getSigners();

      const mockAsset = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
      const mockVault = "0x1111111111111111111111111111111111111111";

      const UserVault = await ethers.getContractFactory("UserVault_V4");
      const vault = await UserVault.deploy(
        owner.address,
        admin.address,
        [mockAsset],
        [mockVault],
        [mockVault],
        revenueAddr.address,
        100,
        1000,
        1000
      );

      await vault.waitForDeployment();

      expect(await vault.SLIPPAGE_TOLERANCE()).to.equal(500); // 5%
    });
  });

  describe("Fee Calculation", function () {
    async function deployVaultFixture() {
      const [owner, admin, revenueAddr] = await ethers.getSigners();

      const mockAsset = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
      const mockVault = "0x1111111111111111111111111111111111111111";

      const UserVault = await ethers.getContractFactory("UserVault_V4");
      const vault = await UserVault.deploy(
        owner.address,
        admin.address,
        [mockAsset],
        [mockVault],
        [mockVault],
        revenueAddr.address,
        100, // 1% fee
        1000, // 10% rebalance fee
        1000 // 10% merkl fee
      );

      await vault.waitForDeployment();

      return { vault, owner, admin, revenueAddr, mockAsset };
    }

    it("Should return zero fee when no profit", async function () {
      const { vault, mockAsset } = await loadFixture(deployVaultFixture);

      // Simulate: deposited 1000, withdrawing 900 (loss)
      const [feeAmount, userAmount] = await vault.calculateFeeFromProfit(
        mockAsset,
        900n
      );

      expect(feeAmount).to.equal(0);
      expect(userAmount).to.equal(900);
    });

    it("Should return zero fee when no initial deposit", async function () {
      const { vault, mockAsset } = await loadFixture(deployVaultFixture);

      const [feeAmount, userAmount] = await vault.calculateFeeFromProfit(
        mockAsset,
        1000n
      );

      expect(feeAmount).to.equal(0);
      expect(userAmount).to.equal(1000);
    });
  });

  describe("View Functions", function () {
    async function deployVaultFixture() {
      const [owner, admin, revenueAddr] = await ethers.getSigners();

      const USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
      const WETH = "0x4200000000000000000000000000000000000006";
      const mockVault1 = "0x1111111111111111111111111111111111111111";
      const mockVault2 = "0x2222222222222222222222222222222222222222";
      const mockVault3 = "0x3333333333333333333333333333333333333333";

      const UserVault = await ethers.getContractFactory("UserVault_V4");
      const vault = await UserVault.deploy(
        owner.address,
        admin.address,
        [USDC, WETH],
        [mockVault1, mockVault2],
        [mockVault1, mockVault2, mockVault3],
        revenueAddr.address,
        100,
        1000,
        1000
      );

      await vault.waitForDeployment();

      return { vault, owner, admin, revenueAddr, USDC, WETH, mockVault1, mockVault2, mockVault3 };
    }

    it("Should return correct allowed assets", async function () {
      const { vault, USDC, WETH } = await loadFixture(deployVaultFixture);

      const assets = await vault.getAllowedAssets();
      expect(assets.length).to.equal(2);
      expect(assets[0]).to.equal(USDC);
      expect(assets[1]).to.equal(WETH);
    });

    it("Should return correct allowed vaults", async function () {
      const { vault, mockVault1, mockVault2, mockVault3 } = await loadFixture(deployVaultFixture);

      const vaults = await vault.getAllowedVaults();
      expect(vaults.length).to.equal(3);
      expect(vaults).to.include(mockVault1);
      expect(vaults).to.include(mockVault2);
      expect(vaults).to.include(mockVault3);
    });

    it("Should return correct fee info", async function () {
      const { vault, revenueAddr } = await loadFixture(deployVaultFixture);

      const [revenueAddress, feePercentage, minProfitForFee] = await vault.getFeeInfo();

      expect(revenueAddress).to.equal(revenueAddr.address);
      expect(feePercentage).to.equal(100);
      expect(minProfitForFee).to.equal(10000000n); // 10e6
    });

    it("Should check if asset is allowed", async function () {
      const { vault, USDC } = await loadFixture(deployVaultFixture);

      expect(await vault.isAllowedAsset(USDC)).to.be.true;
      expect(await vault.isAllowedAsset(ethers.ZeroAddress)).to.be.false;
    });

    it("Should check if vault is allowed", async function () {
      const { vault, mockVault1 } = await loadFixture(deployVaultFixture);

      expect(await vault.isAllowedVault(mockVault1)).to.be.true;
      expect(await vault.isAllowedVault(ethers.ZeroAddress)).to.be.false;
    });
  });

  describe("Integration Test Recommendations", function () {
    it("README: Full integration tests require Base mainnet fork", function () {
      console.log("\n" + "=".repeat(70));
      console.log("INTEGRATION TEST RECOMMENDATIONS");
      console.log("=".repeat(70));
      console.log("\nFor complete testing, use Hardhat forking with Base mainnet:");
      console.log("\n1. Set FORKING=true in .env");
      console.log("2. Configure BASE_RPC_URL with a Base RPC endpoint");
      console.log("3. Run tests with:");
      console.log("   npx hardhat test --network hardhat");
      console.log("\nIntegration tests should cover:");
      console.log("  - Actual deposits to Morpho vaults");
      console.log("  - Withdrawals with fee calculations");
      console.log("  - Rebalancing between vaults");
      console.log("  - Merkl reward claiming");
      console.log("  - Token swaps via Aerodrome");
      console.log("  - Multi-asset operations");
      console.log("\nRequired actual contract addresses:");
      console.log("  - USDC, WETH, cbBTC token contracts");
      console.log("  - Morpho vaults for each asset");
      console.log("  - Merkl distributor and proofs");
      console.log("=".repeat(70) + "\n");
    });
  });
});
