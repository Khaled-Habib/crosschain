require("dotenv").config();

require('hardhat-contract-sizer');
require("@nomiclabs/hardhat-waffle");
require(`@nomiclabs/hardhat-etherscan`);
require("solidity-coverage");
require('hardhat-gas-reporter');
require('hardhat-deploy');
require('hardhat-deploy-ethers');
require('@openzeppelin/hardhat-upgrades');

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();
  
    for (const account of accounts) {
      console.log(account.address);
    }
  });
  
  function getMnemonic(networkName) {
    if (networkName) {
      const mnemonic = process.env['MNEMONIC_' + networkName.toUpperCase()]
      if (mnemonic && mnemonic !== '') {
        return mnemonic
      }
    }
  
    const mnemonic = process.env.MNEMONIC
    if (!mnemonic || mnemonic === '') {
      return 'test test test test test test test test test test test junk'
    }
  
    return mnemonic
  }
  
  function accounts(chainKey) {
    return { mnemonic: getMnemonic(chainKey) }
  }
  

module.exports = {

    solidity: {
      compilers: [
        {
          version: "0.8.4",
          settings: {
            optimizer: {
              enabled: true,
              runs: 200
            }
          }
        },
        {
          version: "0.8.12",
          settings: {
            optimizer: {
              enabled: true,
              runs: 200
            }
          }
        }
      ]
  
  
    },
  
    // solidity: "0.8.4",
    contractSizer: {
      alphaSort: false,
      runOnCompile: true,
      disambiguatePaths: false,
    },
  
    namedAccounts: {
      deployer: {
        default: 0,    // wallet address 0, of the mnemonic in .env
      },
      proxyOwner: {
        default: 1,
      },
    },
  
    networks: {  
      goerli: {
        url: "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161", // public infura endpoint
        chainId: 5,
        accounts: accounts(),
      },
      mumbai: {
        url: "https://rpc-mumbai.maticvigil.com/",
        chainId: 80001,
        accounts: accounts(),
      }
    }
  };