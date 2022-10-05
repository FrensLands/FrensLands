import { HardhatUserConfig } from "hardhat/types";
import "@shardlabs/starknet-hardhat-plugin";
import "@nomiclabs/hardhat-ethers";
require("dotenv").config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
  solidity: "0.6.12",
  starknet: {
    dockerizedVersion: "0.10.0", // alternatively choose one of the two venv options below
    network: "devnet",
    wallets: {
      OpenZeppelin: {
        accountName: "OpenZeppelin",
        modulePath:
          "starkware.starknet.wallets.open_zeppelin.OpenZeppelinAccount",
        accountPath: "~/.starknet_accounts",
      },
    },
  },
  networks: {
    devnet: {
      url: "http://127.0.0.1:5050",
    },
    integratedDevnet: {
      url: "http://127.0.0.1:5050",
      // venv: "active",
      // dockerizedVersion: "latest",
    },
    hardhat: {},
  },
};

export default config;
