const hre = require("hardhat");

async function main() {
  const Arbitrage = await hre.ethers.getContractFactory("ArbitrageExecutor");
  const arbitrage = await Arbitrage.deploy();

  await arbitrage.waitForDeployment();

  console.log(`Arbitrage Executor deployed to: ${await arbitrage.getAddress()}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
