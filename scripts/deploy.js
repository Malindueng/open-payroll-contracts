require("dotenv").config();
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  const OpenPayroll = await hre.ethers.getContractFactory("OpenPayroll");
  const contract = await OpenPayroll.deploy();
  await contract.waitForDeployment();

  const address = await contract.getAddress();
  console.log("OpenPayroll deployed to:", address);
  console.log("Save this address — you'll need it for the DApp.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});