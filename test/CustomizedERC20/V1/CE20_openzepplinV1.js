const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CE20_OPV1", function () {
  let CE20_OPV1;
  let owner, addr1, addr2;
  const initialSupply = ethers.parseEther("1000");
  const mintAmount = ethers.parseEther("500");
  const burnAmount = ethers.parseEther("200");

  before(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    const Contract = await ethers.getContractFactory("CE20_OPV1");
    CE20_OPV1 = await Contract.deploy(initialSupply);
    await CE20_OPV1.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should assign initial supply to owner", async function () {
      expect(await CE20_OPV1.balanceOf(owner.address)).to.equal(initialSupply);
    });

    it("Should set correct token name and symbol", async function () {
      expect(await CE20_OPV1.name()).to.equal("CE20_OPV1");
      expect(await CE20_OPV1.symbol()).to.equal("CE20_OPV1");
    });

    it("Should set correct owner", async function () {
      expect(await CE20_OPV1.owner()).to.equal(owner.address);
    });
  });

  describe("Mint Functionality", function () {
    it("Owner should mint tokens to address", async function () {
      const tx = await CE20_OPV1.connect(owner).mint(addr1.address, mintAmount);
      await expect(tx)
        .to.emit(CE20_OPV1, "Mint")
        .withArgs(addr1.address, mintAmount);

      expect(await CE20_OPV1.balanceOf(addr1.address)).to.equal(mintAmount);
    });

    it("Non-owner should fail to mint", async function () {
      await expect(
        CE20_OPV1.connect(addr1).mint(addr1.address, mintAmount)
      ).to.be.revertedWithCustomError(CE20_OPV1, "OwnableUnauthorizedAccount");
    });
  });

  describe("Burn Functionality", function () {
    before(async function () {
      // Ensure addr1 has balance to burn
      await CE20_OPV1.connect(owner).mint(addr1.address, burnAmount);
    });

    it("Owner should burn tokens from address", async function () {
      const initialBalance = await CE20_OPV1.balanceOf(addr1.address);

      const tx = await CE20_OPV1.connect(owner).burn(addr1.address, burnAmount);
      await expect(tx)
        .to.emit(CE20_OPV1, "Burn")
        .withArgs(addr1.address, burnAmount);

      expect(await CE20_OPV1.balanceOf(addr1.address)).to.equal(
        initialBalance - burnAmount
      );
    });

    it("Should fail when burning more than balance", async function () {
      await expect(
        CE20_OPV1.connect(owner).burn(addr1.address, ethers.MaxUint256)
      ).to.be.revertedWithCustomError(CE20_OPV1, "ERC20InsufficientBalance");
    });

    it("Non-owner should fail to burn", async function () {
      await expect(
        CE20_OPV1.connect(addr1).burn(owner.address, burnAmount)
      ).to.be.revertedWithCustomError(CE20_OPV1, "OwnableUnauthorizedAccount");
    });
  });

  describe("ERC20 Standard Functionality", function () {
    before(async function () {
      // Reset addr1's balance to 0
      await CE20_OPV1.connect(owner).burn(addr1.address, await CE20_OPV1.balanceOf(addr1.address));
    });

    it("Should transfer tokens between accounts", async function () {
      const transferAmount = ethers.parseEther("100");

      // Owner sends to addr1
      await CE20_OPV1.connect(owner).transfer(addr1.address, transferAmount);
      console.log(await CE20_OPV1.balanceOf(addr1.address));
      expect(await CE20_OPV1.balanceOf(addr1.address)).to.equal(transferAmount);

      // Addr1 sends to addr2
      await CE20_OPV1.connect(addr1).transfer(addr2.address, transferAmount);
      expect(await CE20_OPV1.balanceOf(addr2.address)).to.equal(transferAmount);
    });

    it("Should fail transfer when insufficient balance", async function () {
      const invalidAmount = ethers.parseEther("10000");

      await expect(
        CE20_OPV1.connect(addr2).transfer(owner.address, invalidAmount)
      ).to.be.revertedWithCustomError(CE20_OPV1, "ERC20InsufficientBalance");
    });

    it("Should update allowances", async function () {
      const approveAmount = ethers.parseEther("50");

      await CE20_OPV1.connect(addr1).approve(addr2.address, approveAmount);
      expect(await CE20_OPV1.allowance(addr1.address, addr2.address)).to.equal(
        approveAmount
      );
    });
  });

  describe("Ownership Management", function () {
    before(async function () {
      // 清空addr1和addr2的余额
      await CE20_OPV1.connect(owner).burn(addr1.address, await CE20_OPV1.balanceOf(addr1.address));
      await CE20_OPV1.connect(owner).burn(addr2.address, await CE20_OPV1.balanceOf(addr2.address));
    });
    it("Should transfer ownership", async function () {
      await CE20_OPV1.connect(owner).transferOwnership(addr1.address);
      expect(await CE20_OPV1.owner()).to.equal(addr1.address);
    });

    it("New owner should have mint permissions", async function () {
      await CE20_OPV1.connect(addr1).mint(addr2.address, mintAmount);
      expect(await CE20_OPV1.balanceOf(addr2.address)).to.equal(mintAmount);
    });
  });
});
