// @ts-ignore
import { ethers } from "hardhat";

async function main() {
  // deploy token
  const usdc = await ethers.deployContract("Token", ["USDC", "USDC"]);
  await usdc.waitForDeployment();
  console.log("USDC deployed to", usdc.target);
  const btc = await ethers.deployContract("Token", ["BTC", "BTC"]);
  await btc.waitForDeployment();
  console.log("BTC deployed to", btc.target);
  const eth = await ethers.deployContract("Token", ["WETH", "WETH"]);
  await eth.waitForDeployment();
  console.log("ETH deployed to", eth.target);
  const bnb = await ethers.deployContract("Token", ["BNB", "BNB"]);
  await bnb.waitForDeployment();
  console.log("BNB deployed to", bnb.target);
  const sol = await ethers.deployContract("Token", ["SOL", "SOL"]);
  await sol.waitForDeployment();
  console.log("SOL deployed to", sol.target);
  // deploy sap
  const sap = await ethers.deployContract("Sap", [
    "Sap",
    "SAP",
    // https://docs.pyth.network/documentation/pythnet-price-feeds/evm#examples
    "0xA2aa501b19aff244D90cc15a4Cf739D2725B5729",
    [usdc.target, btc.target, eth.target, bnb.target, sol.target],
    // https://pyth.network/developers/price-feed-ids#pyth-evm-stable
    [
      "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a",
      "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43",
      "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace",
      "0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f",
      "0xef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d",
    ],
  ]);
  await sap.waitForDeployment();
  console.log("Sap deployed to", sap.target);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error("deploy error", error);
  process.exitCode = 1;
});
