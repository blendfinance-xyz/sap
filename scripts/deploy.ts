// @ts-ignore
import { ethers } from "hardhat";
import { n2b } from "../utils/math";

async function feeDiscount() {
  const feeDiscount = await ethers.deployContract("FeeDiscount");
  await feeDiscount.waitForDeployment();
  console.log("FeeDiscount deployed to", feeDiscount.target);
}

async function sap() {
  // pyth
  // https://pyth.network/developers/price-feed-ids#pyth-evm-stable
  const pythPriceIds = {
    usdc: "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a",
    btc: "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43",
    weth: "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace",
    bnb: "0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f",
    sol: "0xef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d",
    null: "0x0000000000000000000000000000000000000000000000000000000000000000",
  };
  // https://docs.pyth.network/price-feeds/contract-addresses/evm
  const pyth = "0xA2aa501b19aff244D90cc15a4Cf739D2725B5729";
  // uniswap
  const uniswapRouter = "0xd5e5597068b889e1625171186E6e302c9De36F09";
  // staking
  const staking = "0xD406B0edDDABF1e3fb09fF3588D70836A18d0ef2";
  // fee discount
  const feeDiscount = "0x386c86741D6976fe1225BE47Dc5d094Ad31Ba4D2";
  // tokens
  const tokens = {
    usdc: "0x602FA06D258571BBE03e05Fd09C96035d425757D",
    btc: "0x999465395081B7e57ccda9e1d3CCF6Bd7525CA99",
    weth: "0xf73306A78d66fE18C7a8F5df13aD3f3aA65dE31c",
    bnb: "0x3308A241E42e8B59de1a5f3fA4A1A3Ab2E3d46EF",
    sol: "0xC3C85E25d4a2c451e8C964A13bA7d1a471cD35f5",
    bld: "0xA37E268923652749Ba41DD0bBF6227C276047463",
  };
  // sap
  const sap = await ethers.deployContract("Sap", [
    "AI SAP",
    "AISP",
    n2b(6 / 100.0, 6),
    pyth,
    uniswapRouter,
    staking,
    feeDiscount,
    [
      {
        token: tokens.usdc,
        pythPriceId: pythPriceIds.usdc,
      },
      {
        token: tokens.btc,
        pythPriceId: pythPriceIds.btc,
      },
      {
        token: tokens.weth,
        pythPriceId: pythPriceIds.weth,
      },
      {
        token: tokens.bnb,
        pythPriceId: pythPriceIds.bnb,
      },
      {
        token: tokens.sol,
        pythPriceId: pythPriceIds.sol,
      },
      {
        token: tokens.bld,
        pythPriceId: pythPriceIds.null,
      },
    ],
  ]);
  await sap.waitForDeployment();
  console.log("Sap deployed to", sap.target);
}

async function main() {
  // deploy fee discount
  // await feeDiscount();
  // deploy sap
  await sap();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error("deploy error", error);
  process.exitCode = 1;
});
