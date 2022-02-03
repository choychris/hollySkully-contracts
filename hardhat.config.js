// hardhat.config.js
const { etherscanApiKey } = require('./secrets.json');

require("@nomiclabs/hardhat-etherscan");
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultnetwork: "rinkeby",
  networks: {
    rinkeby: {
      url: ``,
      accounts: {mnemonic: 'aaa aaa aaa'}
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: etherscanApiKey
  },
  solidity: "0.8.0"
};