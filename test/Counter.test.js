
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("coounter", function () {
  beforeEach(async function () {
    // use this chainId
    this.chainId = 123;

  
    const ParentContract = await ethers.getContractFactory("ParentContract");
    this.parent = await ParentContract.deploy(this.chainId);

    // create two OmniCounter instances
    const Counter = await ethers.getContractFactory("Counter");
    this.counterA = await Counter.deploy(this.chainId, this.parent.address);
    this.counterB = await Counter.deploy(this.chainId, this.parent.address);

    this.parent.setDestAddress(this.counterA.address, this.parent.address);
    this.parent.setDestAddress(this.counterB.address, this.parent.address);

    // set each contracts source address so it can send to each other
    this.counterA.trustContract(
      this.chainId,
      ethers.utils.solidityPack(
        ["address", "address"],
        [this.counterB.address, this.counterA.address]
      )
    );
    this.counterB.trustContract(
      this.chainId,
      ethers.utils.solidityPack(
        ["address", "address"],
        [this.counterA.address, this.counterB.address]
      )
    );
  });

  it("increment the counter of the destination Counter", async function () {
    // ensure theyre both starting from 0
    expect(await this.counterA.counter()).to.be.equal(0); // initial value
    expect(await this.counterB.counter()).to.be.equal(0); // initial value

    // instruct each OmniCounter to increment the other OmniCounter
    // counter A increments counter B
    await this.counterA.sending(this.chainId, {
      value: ethers.utils.parseEther("0.5"),
    });
    expect(await this.counterA.counter()).to.be.equal(0); // still 0
    expect(await this.counterB.counter()).to.be.equal(1); // now its 1

    // counter B increments counter A
    await this.counterB.sending(this.chainId, {
      value: ethers.utils.parseEther("0.5"),
    });
    expect(await this.counterA.counter()).to.be.equal(1); // now its 1
    expect(await this.counterB.counter()).to.be.equal(1); // still 1
  });
});
