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
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gas: 2100000,
      gasPrice: 20000000000,
      accounts: { mnemonic: '' }
    },
    node_network: {
      url: "http://127.0.0.1:8545",
    },
  },
  etherscan: {
    apiKey: '14C6P9NP9U3Y4T3II3ZFSA49929XHT8R3U'
  }
};

export default config;
