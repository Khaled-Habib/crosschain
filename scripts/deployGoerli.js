// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

    const goerli = 10121;
  
  const ParentContract = await ethers.getContractFactory("ParentContract");
  const goerliParent = await ParentContract.deploy(goerli);
  await goerliParent.deployed();


  console.log(
    `parent deployed to ${goerliParent.address}`
  );
  

  const Counter = await ethers.getContractFactory("Counter");
  const goerliCounter = await Counter.deploy(goerli, this.goerliParent.address);
  await goerliCounter.deployed();


  console.log(
    `counterA deployed to ${goerliCounter.address}`
  );
  
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
