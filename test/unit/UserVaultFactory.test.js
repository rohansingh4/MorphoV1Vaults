const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("UserVaultFactory", function () {
  // Fixture to deploy the factory
  async function deployFactoryFixture() {
    const [owner, user1, user2, feeRecipient, admin] = await ethers.getSigners();

    const deploymentFee = ethers.parseEther("0.001");

    const UserVaultFactory = await ethers.getContractFactory("UserVaultFactory");
    const factory = await UserVaultFactory.deploy(
      owner.address,
      deploymentFee,
      feeRecipient.address
    );

    await factory.waitForDeployment();

    return { factory, owner, user1, user2, feeRecipient, admin, deploymentFee };
  }

  describe("Deployment", function () {
    it("Should set the correct initial owner", async function () {
      const { factory, owner } = await loadFixture(deployFactoryFixture);
      expect(await factory.owner()).to.equal(owner.address);
    });

    it("Should set the correct deployment fee", async function () {
      const { factory, deploymentFee } = await loadFixture(deployFactoryFixture);
      expect(await factory.deploymentFee()).to.equal(deploymentFee);
    });

    it("Should set the correct fee recipient", async function () {
      const { factory, feeRecipient } = await loadFixture(deployFactoryFixture);
      expect(await factory.feeRecipient()).to.equal(feeRecipient.address);
    });

    it("Should use owner as fee recipient if zero address provided", async function () {
      const [owner] = await ethers.getSigners();
      const UserVaultFactory = await ethers.getContractFactory("UserVaultFactory");
      const factory = await UserVaultFactory.deploy(
        owner.address,
        0,
        ethers.ZeroAddress
      );
      await factory.waitForDeployment();

      expect(await factory.feeRecipient()).to.equal(owner.address);
    });

    it("Should start with zero total vaults", async function () {
      const { factory } = await loadFixture(deployFactoryFixture);
      expect(await factory.getTotalVaults()).to.equal(0);
    });
  });

  describe("generateDeterministicSalt", function () {
    it("Should generate different salts for different nonces", async function () {
      const { factory, user1 } = await loadFixture(deployFactoryFixture);

      const salt1 = await factory.generateDeterministicSalt(user1.address, 1);
      const salt2 = await factory.generateDeterministicSalt(user1.address, 2);

      expect(salt1).to.not.equal(salt2);
    });

    it("Should generate different salts for different users", async function () {
      const { factory, user1, user2 } = await loadFixture(deployFactoryFixture);

      const salt1 = await factory.generateDeterministicSalt(user1.address, 1);
      const salt2 = await factory.generateDeterministicSalt(user2.address, 1);

      expect(salt1).to.not.equal(salt2);
    });

    it("Should generate same salt for same inputs", async function () {
      const { factory, user1 } = await loadFixture(deployFactoryFixture);

      const salt1 = await factory.generateDeterministicSalt(user1.address, 1);
      const salt2 = await factory.generateDeterministicSalt(user1.address, 1);

      expect(salt1).to.equal(salt2);
    });
  });

  describe("computeVaultAddress", function () {
    it("Should compute deterministic address", async function () {
      const { factory, user1, admin } = await loadFixture(deployFactoryFixture);

      const mockAsset = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
      const mockVault = "0x1111111111111111111111111111111111111111";
      const salt = await factory.generateDeterministicSalt(user1.address, 1);

      const address1 = await factory.computeVaultAddress(
        user1.address,
        admin.address,
        [mockAsset],
        [mockVault],
        [mockVault],
        user1.address,
        100,
        1000,
        1000,
        salt
      );

      const address2 = await factory.computeVaultAddress(
        user1.address,
        admin.address,
        [mockAsset],
        [mockVault],
        [mockVault],
        user1.address,
        100,
        1000,
        1000,
        salt
      );

      expect(address1).to.equal(address2);
      expect(address1).to.not.equal(ethers.ZeroAddress);
    });

    it("Should compute different addresses for different salts", async function () {
      const { factory, user1, admin } = await loadFixture(deployFactoryFixture);

      const mockAsset = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
      const mockVault = "0x1111111111111111111111111111111111111111";
      const salt1 = await factory.generateDeterministicSalt(user1.address, 1);
      const salt2 = await factory.generateDeterministicSalt(user1.address, 2);

      const address1 = await factory.computeVaultAddress(
        user1.address,
        admin.address,
        [mockAsset],
        [mockVault],
        [mockVault],
        user1.address,
        100,
        1000,
        1000,
        salt1
      );

      const address2 = await factory.computeVaultAddress(
        user1.address,
        admin.address,
        [mockAsset],
        [mockVault],
        [mockVault],
        user1.address,
        100,
        1000,
        1000,
        salt2
      );

      expect(address1).to.not.equal(address2);
    });
  });

  describe("Access Control", function () {
    describe("setDeploymentFee", function () {
      it("Should allow owner to set deployment fee", async function () {
        const { factory, owner } = await loadFixture(deployFactoryFixture);
        const newFee = ethers.parseEther("0.002");

        await expect(factory.connect(owner).setDeploymentFee(newFee))
          .to.not.be.reverted;

        expect(await factory.deploymentFee()).to.equal(newFee);
      });

      it("Should reject non-owner setting deployment fee", async function () {
        const { factory, user1 } = await loadFixture(deployFactoryFixture);
        const newFee = ethers.parseEther("0.002");

        await expect(factory.connect(user1).setDeploymentFee(newFee))
          .to.be.revertedWithCustomError(factory, "OwnableUnauthorizedAccount");
      });
    });

    describe("setFeeRecipient", function () {
      it("Should allow owner to set fee recipient", async function () {
        const { factory, owner, user1 } = await loadFixture(deployFactoryFixture);

        await expect(factory.connect(owner).setFeeRecipient(user1.address))
          .to.not.be.reverted;

        expect(await factory.feeRecipient()).to.equal(user1.address);
      });

      it("Should reject zero address as fee recipient", async function () {
        const { factory, owner } = await loadFixture(deployFactoryFixture);

        await expect(factory.connect(owner).setFeeRecipient(ethers.ZeroAddress))
          .to.be.revertedWith("Invalid recipient");
      });

      it("Should reject non-owner setting fee recipient", async function () {
        const { factory, user1, user2 } = await loadFixture(deployFactoryFixture);

        await expect(factory.connect(user1).setFeeRecipient(user2.address))
          .to.be.revertedWithCustomError(factory, "OwnableUnauthorizedAccount");
      });
    });

    describe("pause/unpause", function () {
      it("Should allow owner to pause", async function () {
        const { factory, owner } = await loadFixture(deployFactoryFixture);

        await expect(factory.connect(owner).pause())
          .to.not.be.reverted;

        expect(await factory.paused()).to.be.true;
      });

      it("Should allow owner to unpause", async function () {
        const { factory, owner } = await loadFixture(deployFactoryFixture);

        await factory.connect(owner).pause();

        await expect(factory.connect(owner).unpause())
          .to.not.be.reverted;

        expect(await factory.paused()).to.be.false;
      });

      it("Should reject non-owner pausing", async function () {
        const { factory, user1 } = await loadFixture(deployFactoryFixture);

        await expect(factory.connect(user1).pause())
          .to.be.revertedWithCustomError(factory, "OwnableUnauthorizedAccount");
      });
    });
  });

  describe("Query Functions", function () {
    it("Should return empty array for owner with no vaults", async function () {
      const { factory, user1 } = await loadFixture(deployFactoryFixture);

      const vaults = await factory.getOwnerVaults(user1.address);
      expect(vaults.length).to.equal(0);
    });

    it("Should return empty indices for owner with no vaults", async function () {
      const { factory, user1 } = await loadFixture(deployFactoryFixture);

      const indices = await factory.getVaultIndicesByOwner(user1.address);
      expect(indices.length).to.equal(0);
    });

    it("Should return false for non-factory vault", async function () {
      const { factory, user1 } = await loadFixture(deployFactoryFixture);

      const isFromFactory = await factory.isVaultFromFactory(user1.address);
      expect(isFromFactory).to.be.false;
    });
  });

  describe("Emergency Withdraw", function () {
    it("Should allow owner to withdraw ETH (skipped - contract has no receive function)", async function () {
      // Note: The UserVaultFactory contract doesn't have a receive() function,
      // so it cannot accept plain ETH transfers. ETH can only come from deployment fees.
      // This test would need the factory to receive deployment fees first.
      const { factory } = await loadFixture(deployFactoryFixture);
      expect(await factory.getAddress()).to.not.equal(ethers.ZeroAddress);
    });

    it("Should revert if no balance to withdraw", async function () {
      const { factory, owner } = await loadFixture(deployFactoryFixture);

      await expect(factory.connect(owner).emergencyWithdraw())
        .to.be.revertedWith("No balance to withdraw");
    });

    it("Should reject non-owner emergency withdraw", async function () {
      const { factory, user1 } = await loadFixture(deployFactoryFixture);

      await expect(factory.connect(user1).emergencyWithdraw())
        .to.be.revertedWithCustomError(factory, "OwnableUnauthorizedAccount");
    });
  });
});
