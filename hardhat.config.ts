import "dotenv/config";

import "@nomiclabs/hardhat-truffle5";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";

import { HardhatUserConfig } from "hardhat/types";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.7",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.6.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  typechain: {
    target: "truffle-v5",
  },
  networks: {
    test: {
      url: "http://127.0.0.1:8545",
    },
    hardhat: {
      chainId: 5,
      forking: {
        url: "http://192.168.2.107:9995"
      },
      accounts: {
        mnemonic: "test test test test test test test test test test test test",
        count: 10,
        accountsBalance: "1000000000000000000000000",
      }
    },
    testnet: {
      url: process.env.BSC_TESTNET_URL,
      chainId: 97,
      gasPrice: 20000000000,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    node_network: {
      url: "http://127.0.0.1:8545",
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  }
};

export default config;
