const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("Gesell", function () {
  let gesell;
  let usdc;
  let owner;
  let user1;
  let user2;
  let feeRecipient;
  
  const MINT_PRICE = 37_070_000; // 37.07 USDC per GSLL
  const TRANSACTION_FEE = 10_000; // 0.01 USDC/GSLL
  const DECAY_PERIOD = 300_000; // seconds
  
  beforeEach(async function () {
    [owner, user1, user2, feeRecipient] = await ethers.getSigners();
    
    // Deploy mock USDC
    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    usdc = await MockUSDC.deploy();
    await usdc.waitForDeployment();
    
    // Deploy Gesell
    const Gesell = await ethers.getContractFactory("Gesell");
    gesell = await Gesell.deploy(
      await usdc.getAddress(),
      MINT_PRICE,
      feeRecipient.address
    );
    await gesell.waitForDeployment();
    
    // Mint some USDC to users for testing
    await usdc.mint(user1.address, ethers.parseUnits("10000", 6));
    await usdc.mint(user2.address, ethers.parseUnits("10000", 6));
    
    // Approve Gesell to spend USDC
    await usdc.connect(user1).approve(await gesell.getAddress(), ethers.MaxUint256);
    await usdc.connect(user2).approve(await gesell.getAddress(), ethers.MaxUint256);
  });

  describe("Deployment", function () {
    it("Should set the correct name and symbol", async function () {
      expect(await gesell.name()).to.equal("Gesell");
      expect(await gesell.symbol()).to.equal("GSLL");
    });

    it("Should set the correct decimals", async function () {
      expect(await gesell.decimals()).to.equal(6);
    });

    it("Should set the correct mint price", async function () {
      expect(await gesell.mintPrice()).to.equal(MINT_PRICE);
    });

    it("Should set the correct fee recipient", async function () {
      expect(await gesell.feeRecipient()).to.equal(feeRecipient.address);
    });
  });

  describe("Minting", function () {
    it("Should mint GSLL when depositing USDC", async function () {
      const usdcAmount = ethers.parseUnits("100", 6); // 100 USDC
      
      await gesell.connect(user1).mint(usdcAmount);
      
      // Expected GSLL: (100 - 0.01) / 37.07 = ~2.696 GSLL
      const balance = await gesell.balanceOf(user1.address);
      expect(balance).to.be.gt(0);
    });

    it("Should transfer fee to fee recipient", async function () {
      const usdcAmount = ethers.parseUnits("100", 6);
      const feeBalanceBefore = await usdc.balanceOf(feeRecipient.address);
      
      await gesell.connect(user1).mint(usdcAmount);
      
      const feeBalanceAfter = await usdc.balanceOf(feeRecipient.address);
      expect(feeBalanceAfter - feeBalanceBefore).to.equal(TRANSACTION_FEE);
    });

    it("Should preview mint correctly", async function () {
      const usdcAmount = ethers.parseUnits("100", 6);
      const preview = await gesell.previewMint(usdcAmount);
      
      // (100 - 0.01) * 10^6 / 37.07 * 10^6
      const expected = ((100_000_000n - 10_000n) * 1_000_000n) / 37_070_000n;
      expect(preview).to.equal(expected);
    });

    it("Should fail if amount doesn't cover fee", async function () {
      const usdcAmount = TRANSACTION_FEE; // Exactly the fee
      await expect(gesell.connect(user1).mint(usdcAmount))
        .to.be.revertedWith("Amount must cover fee");
    });
  });

  describe("Decay", function () {
    it("Should decay balance over time", async function () {
      const usdcAmount = ethers.parseUnits("1000", 6);
      await gesell.connect(user1).mint(usdcAmount);
      
      const balanceBefore = await gesell.balanceOf(user1.address);
      
      // Fast forward 1 decay period (300,000 seconds)
      await time.increase(DECAY_PERIOD);
      
      const balanceAfter = await gesell.balanceOf(user1.address);
      
      // Balance should be 99.99% of before
      expect(balanceAfter).to.be.lt(balanceBefore);
      
      // Check it's approximately 0.01% less
      const expectedAfter = (balanceBefore * 9999n) / 10000n;
      expect(balanceAfter).to.be.closeTo(expectedAfter, 1);
    });

    it("Should compound decay over multiple periods", async function () {
      const usdcAmount = ethers.parseUnits("1000", 6);
      await gesell.connect(user1).mint(usdcAmount);
      
      const balanceBefore = await gesell.balanceOf(user1.address);
      
      // Fast forward 10 decay periods
      await time.increase(DECAY_PERIOD * 10);
      
      const balanceAfter = await gesell.balanceOf(user1.address);
      
      // Should be approximately (0.9999)^10 = ~99.9% of original
      expect(balanceAfter).to.be.lt(balanceBefore);
    });

    it("Should return correct periods elapsed", async function () {
      expect(await gesell.periodsElapsed()).to.equal(0);
      
      await time.increase(DECAY_PERIOD);
      expect(await gesell.periodsElapsed()).to.equal(1);
      
      await time.increase(DECAY_PERIOD * 5);
      expect(await gesell.periodsElapsed()).to.equal(6);
    });
  });

  describe("Transfers", function () {
    beforeEach(async function () {
      const usdcAmount = ethers.parseUnits("1000", 6);
      await gesell.connect(user1).mint(usdcAmount);
    });

    it("Should transfer GSLL between accounts", async function () {
      const transferAmount = ethers.parseUnits("1", 6); // 1 GSLL
      
      await gesell.connect(user1).transfer(user2.address, transferAmount);
      
      const user2Balance = await gesell.balanceOf(user2.address);
      expect(user2Balance).to.equal(transferAmount);
    });

    it("Should deduct transfer fee", async function () {
      const balanceBefore = await gesell.balanceOf(user1.address);
      const transferAmount = ethers.parseUnits("1", 6);
      
      await gesell.connect(user1).transfer(user2.address, transferAmount);
      
      const balanceAfter = await gesell.balanceOf(user1.address);
      
      // Should have lost transferAmount + fee
      expect(balanceBefore - balanceAfter).to.equal(transferAmount + BigInt(TRANSACTION_FEE));
    });

    it("Should fail if balance doesn't cover amount + fee", async function () {
      const balance = await gesell.balanceOf(user1.address);
      
      await expect(gesell.connect(user1).transfer(user2.address, balance))
        .to.be.revertedWith("Insufficient balance (including fee)");
    });
  });

  describe("Redemption", function () {
    beforeEach(async function () {
      const usdcAmount = ethers.parseUnits("1000", 6);
      await gesell.connect(user1).mint(usdcAmount);
    });

    it("Should redeem GSLL for USDC", async function () {
      const gsllBalance = await gesell.balanceOf(user1.address);
      const usdcBefore = await usdc.balanceOf(user1.address);
      
      await gesell.connect(user1).redeem(gsllBalance);
      
      const usdcAfter = await usdc.balanceOf(user1.address);
      expect(usdcAfter).to.be.gt(usdcBefore);
    });

    it("Should preview redeem correctly", async function () {
      const gsllAmount = ethers.parseUnits("1", 6); // 1 GSLL
      const preview = await gesell.previewRedeem(gsllAmount);
      
      // 1 GSLL * 37.07 - 0.01 fee = ~37.06 USDC
      const expected = (1_000_000n * 37_070_000n) / 1_000_000n - 10_000n;
      expect(preview).to.equal(expected);
    });
  });

  describe("Admin Functions", function () {
    it("Should allow owner to update mint price", async function () {
      const newPrice = 40_000_000; // 40 USDC
      await gesell.connect(owner).updateMintPrice(newPrice);
      expect(await gesell.mintPrice()).to.equal(newPrice);
    });

    it("Should not allow non-owner to update mint price", async function () {
      await expect(gesell.connect(user1).updateMintPrice(40_000_000))
        .to.be.reverted;
    });

    it("Should allow owner to update fee recipient", async function () {
      await gesell.connect(owner).setFeeRecipient(user2.address);
      expect(await gesell.feeRecipient()).to.equal(user2.address);
    });
  });
});

// Mock USDC contract for testing
const MockUSDCArtifact = {
  abi: [
    "function mint(address to, uint256 amount) external",
    "function balanceOf(address account) external view returns (uint256)",
    "function approve(address spender, uint256 amount) external returns (bool)",
    "function transfer(address to, uint256 amount) external returns (bool)",
    "function transferFrom(address from, address to, uint256 amount) external returns (bool)",
    "function allowance(address owner, address spender) external view returns (uint256)"
  ]
};
