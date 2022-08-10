require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config({ path: __dirname + '/.env' });


const ALCHEMY_API_KEY_URL = process.env.ALCHEMY_API_KEY_URL
const ACCOUNT_PRIVATE_KEY = process.env.ACCOUNT_PRIVATE_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.6",
  networks: {
    goerli: {
      url: ALCHEMY_API_KEY_URL,
      accounts: [ACCOUNT_PRIVATE_KEY],
    },
  },
};
