// @ts-ignore
import { ethers } from "hardhat";
import { n2b } from "../utils/math";

async function sap() {
  // tokens
  const usdc = await ethers.deployContract("Token", ["USDC", "USDC"]);
  console.log("USDC deployed to", usdc.target);
  const btc = await ethers.deployContract("Token", ["Bitcoin", "BTC"]);
  console.log("BTC deployed to", btc.target);
  const weth = await ethers.deployContract("Token", ["Wrapped ETH", "WETH"]);
  console.log("WETH deployed to", weth.target);
  const bnb = await ethers.deployContract("Token", ["BNB", "BNB"]);
  console.log("BNB deployed to", bnb.target);
  const sol = await ethers.deployContract("Token", ["Solana", "SOL"]);
  console.log("SOL deployed to", sol.target);
  const bld = await ethers.deployContract("Token", ["Blend", "BLD"]);
  console.log("BLD deployed to", bld.target);
  // pyth
  const pyth = await ethers.deployContract("Pyth");
  console.log("Pyth deployed to", pyth.target);
  // https://docs.pyth.network/documentation/pythnet-price-feeds/evm#examples
  // const pyth = { target: "0xA2aa501b19aff244D90cc15a4Cf739D2725B5729" };
  // https://pyth.network/developers/price-feed-ids#pyth-evm-stable
  const pythPriceIds = {
    usdc: "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a",
    btc: "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43",
    weth: "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace",
    bnb: "0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f",
    sol: "0xef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d",
    null: "0x0000000000000000000000000000000000000000000000000000000000000000",
  };
  // uniswap
  const uniswapFactory = await ethers.deployContract("UniswapV2Factory", [
    bld.target,
  ]);
  console.log("UniswapV2Factory deployed to", uniswapFactory.target);
  const uniswapRouter = await ethers.deployContract("UniswapV2Router02", [
    uniswapFactory.target,
    weth.target,
  ]);
  console.log("UniswapV2Router02 deployed to", uniswapRouter.target);
  // staking
  const staking = await ethers.deployContract("Staking", [bld.target]);
  console.log("Staking deployed to", staking.target);
  // fee discount
  const feeDiscount = await ethers.deployContract("FeeDiscount");
  console.log("FeeDiscount deployed to", feeDiscount.target);
  // sap
  const sap = await ethers.deployContract("Sap", [
    "Sap",
    "SAP",
    n2b(6 / 100.0, 6),
    pyth.target,
    uniswapRouter.target,
    staking.target,
    feeDiscount.target,
    [
      { token: usdc.target, pythPriceId: pythPriceIds.usdc },
      {
        token: btc.target,
        pythPriceId: pythPriceIds.btc,
      },
      {
        token: weth.target,
        pythPriceId: pythPriceIds.weth,
      },
      {
        token: bnb.target,
        pythPriceId: pythPriceIds.bnb,
      },
      {
        token: sol.target,
        pythPriceId: pythPriceIds.sol,
      },
      {
        token: bld.target,
        pythPriceId: pythPriceIds.null,
      },
    ],
  ]);
  await sap.waitForDeployment();
  console.log("Sap deployed to", sap.target);
}

// 0x8f86403a4de0bb5791fa46b8e795c547942fe4cf

async function main() {
  // deploy sap
  await sap();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error("deploy error", error);
  process.exitCode = 1;
});
