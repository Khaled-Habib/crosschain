// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

    const mumbai = 10109; //todo
  
  const ParentContract = await ethers.getContractFactory("ParentContract");
  const mumbaiParent = await ParentContract.deploy(mumbai);
  await mumbaiParent.deployed();


  console.log(
    `parent deployed to ${mumbaiParent.address}`
  );


  const Counter = await ethers.getContractFactory("Counter");
  const mumbaiCounter = await Counter.deploy(mumbai, this.mumbaiParent.address);
  await mumbaiCounter.deployed();


  console.log(
    `CounterA deployed to ${mumbaiCounter.address}`
  );


}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
