import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { ContractFactory } from "ethers";
import { describe, test } from "mocha";
import assert, { strictEqual } from "node:assert";
import { Sap as SapContract } from "../typechain-types/contracts/Sap";
import { Token as TokenContract } from "../typechain-types/contracts/Token";
import { Pyth as PythContract } from "../typechain-types/contracts/Pyth";

// @ts-ignore
import { ethers } from "hardhat";

// all time on chain is in second
const DAY_MULTIPLIER = 24 * 60 * 60;

function n2b(n: number, decimals: number | bigint): bigint {
  const ns = n.toString();
  let [int, dec] = ns.split(".");
  if (int === "0") int = "";
  if (!dec) dec = "";
  if (dec.length <= Number(decimals)) {
    dec = dec.padEnd(Number(decimals), "0");
  } else {
    dec = dec.slice(0, Number(decimals));
  }
  return BigInt(`${int}${dec}`);
}

function b2n(b: bigint, decimals: number | bigint): number {
  const bs = b.toString();
  if (bs.length <= Number(decimals)) {
    return parseFloat(`0.${bs.padStart(Number(decimals), "0")}`);
  } else {
    return parseFloat(
      `${bs.slice(0, bs.length - Number(decimals))}.${bs.slice(bs.length - Number(decimals))}`,
    );
  }
}

function assertNumber(a: number, b: number, msg?: string) {
  strictEqual(a.toFixed(3), b.toFixed(3), msg);
}

async function deploy() {
  const [owner, otherAccount] = await ethers.getSigners();
  // token
  const Token: ContractFactory = await ethers.getContractFactory("Token");
  const usdc = (await Token.deploy("USDC", "USDC")) as TokenContract;
  const btc = (await Token.deploy("Bitcoin", "BTC")) as TokenContract;
  const weth = (await Token.deploy("Wrapped ETH", "WETH")) as TokenContract;
  const bnb = (await Token.deploy("BNB", "BNB")) as TokenContract;
  const sol = (await Token.deploy("Solana", "SOL")) as TokenContract;
  const initAmount = 1000n * 10n ** 18n;
  await usdc.mint(owner.address, initAmount);
  await btc.mint(owner.address, initAmount);
  await weth.mint(owner.address, initAmount);
  await bnb.mint(owner.address, initAmount);
  await sol.mint(owner.address, initAmount);
  await usdc.mint(otherAccount.address, initAmount);
  await btc.mint(otherAccount.address, initAmount);
  await weth.mint(otherAccount.address, initAmount);
  await bnb.mint(otherAccount.address, initAmount);
  await sol.mint(otherAccount.address, initAmount);
  // pyth
  const pythPriceIds = {
    usdc: "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a",
    btc: "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43",
    weth: "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace",
    bnb: "0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f",
    sol: "0xef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d",
  };
  const pythPrices = {
    usdc: 0.9999,
    btc: 41671.75,
    weth: 2474.97,
    bnb: 317.95,
    sol: 91.55,
  };
  const Pyth: ContractFactory = await ethers.getContractFactory("Pyth");
  const pyth = (await Pyth.deploy()) as PythContract;
  await pyth.putPrice(pythPriceIds.usdc, n2b(pythPrices.usdc, 6), -6);
  await pyth.putPrice(pythPriceIds.btc, n2b(pythPrices.btc, 6), -6);
  await pyth.putPrice(pythPriceIds.weth, n2b(pythPrices.weth, 6), -6);
  await pyth.putPrice(pythPriceIds.bnb, n2b(pythPrices.bnb, 6), -6);
  await pyth.putPrice(pythPriceIds.sol, n2b(pythPrices.sol, 6), -6);
  // sap
  const sapInitAmount = {
    usdc: n2b(100, await usdc.decimals()),
    btc: n2b(1, await btc.decimals()),
    weth: n2b(2, await weth.decimals()),
    bnb: n2b(3, await bnb.decimals()),
    sol: n2b(4, await sol.decimals()),
    sap: n2b(100, 18),
  };
  const Sap: ContractFactory = await ethers.getContractFactory("Sap");
  const sap = (await Sap.deploy("Sap", "SAP", await pyth.getAddress(), [
    {
      token: await usdc.getAddress(),
      priceId: pythPriceIds.usdc,
    },
    {
      token: await btc.getAddress(),
      priceId: pythPriceIds.btc,
    },
    {
      token: await weth.getAddress(),
      priceId: pythPriceIds.weth,
    },
    {
      token: await bnb.getAddress(),
      priceId: pythPriceIds.bnb,
    },
    {
      token: await sol.getAddress(),
      priceId: pythPriceIds.sol,
    },
  ])) as SapContract;
  return {
    owner,
    otherAccount,
    initAmount,
    usdc,
    btc,
    weth,
    bnb,
    sol,
    pythPriceIds,
    pythPrices,
    pyth,
    sap,
    sapInitAmount,
  };
}

describe("deploy test", () => {
  test("should be mint right amount", async () => {
    const { owner, otherAccount, initAmount, usdc } = await loadFixture(deploy);
    const ownerTokenBalance = await usdc.balanceOf(owner.address);
    const otherTokenBalance = await usdc.balanceOf(otherAccount.address);
    strictEqual(ownerTokenBalance.toString(), initAmount.toString());
    strictEqual(otherTokenBalance.toString(), initAmount.toString());
  });
  test("should be right owner", async () => {
    const { owner, sap } = await loadFixture(deploy);
    strictEqual(await sap.owner(), owner.address, "sap owner is not right");
  });
  test("should be right token", async () => {
    const { usdc, btc, weth, bnb, sol, sap } = await loadFixture(deploy);
    strictEqual(
      await usdc.getAddress(),
      await sap.getAssetToken(0),
      "sap token 0 is not right",
    );
    strictEqual(
      await btc.getAddress(),
      await sap.getAssetToken(1),
      "sap token 1 is not right",
    );
    strictEqual(
      await weth.getAddress(),
      await sap.getAssetToken(2),
      "sap token 2 is not right",
    );
    strictEqual(
      await bnb.getAddress(),
      await sap.getAssetToken(3),
      "sap token 3 is not right",
    );
    strictEqual(
      await sol.getAddress(),
      await sap.getAssetToken(4),
      "sap token 4 is not right",
    );
  });
  test("should be right pyth price id", async () => {
    const { pythPriceIds, sap } = await loadFixture(deploy);
    strictEqual(
      pythPriceIds.usdc,
      await sap.getAssetPriceId(0),
      "sap pyth price id 0 is not right",
    );
    strictEqual(
      pythPriceIds.btc,
      await sap.getAssetPriceId(1),
      "sap pyth price id 1 is not right",
    );
    strictEqual(
      pythPriceIds.weth,
      await sap.getAssetPriceId(2),
      "sap pyth price id 2 is not right",
    );
    strictEqual(
      pythPriceIds.bnb,
      await sap.getAssetPriceId(3),
      "sap pyth price id 3 is not right",
    );
    strictEqual(
      pythPriceIds.sol,
      await sap.getAssetPriceId(4),
      "sap pyth price id 4 is not right",
    );
  });
});

describe("pyth test", () => {
  test("should be right price", async () => {
    const { pyth, pythPriceIds, pythPrices } = await loadFixture(deploy);
    async function t(priceId: string, price: number, exponent: number) {
      const p = await pyth.getPrice(priceId);
      strictEqual(
        b2n(p[0], exponent),
        price,
        `pyth price ${priceId} is not right`,
      );
      strictEqual(
        Number(p[2]),
        exponent * -1,
        `pyth price ${priceId} expo is not right`,
      );
    }
    for (let i = 0; i < Object.keys(pythPriceIds).length; i++) {
      await t(Object.values(pythPriceIds)[i], Object.values(pythPrices)[i], 6);
    }
  });
});

describe("business test", () => {
  async function init() {
    const { owner, usdc, btc, weth, bnb, sol, sap, sapInitAmount, ...rest } =
      await loadFixture(deploy);
    const sapAddress = await sap.getAddress();
    await usdc.approve(sapAddress, sapInitAmount.usdc);
    await btc.approve(sapAddress, sapInitAmount.btc);
    await weth.approve(sapAddress, sapInitAmount.weth);
    await bnb.approve(sapAddress, sapInitAmount.bnb);
    await sol.approve(sapAddress, sapInitAmount.sol);
    await sap.init(
      [
        sapInitAmount.usdc,
        sapInitAmount.btc,
        sapInitAmount.weth,
        sapInitAmount.bnb,
        sapInitAmount.sol,
      ],
      sapInitAmount.sap,
    );
    return { owner, usdc, btc, weth, bnb, sol, sap, sapInitAmount, ...rest };
  }
  test("should init right", async () => {
    const { owner, usdc, btc, weth, bnb, sol, sap, sapInitAmount } =
      await init();
    const sapAddress = await sap.getAddress();
    strictEqual(
      await usdc.balanceOf(sapAddress),
      sapInitAmount.usdc,
      "sap asset 0 amount not right",
    );
    strictEqual(
      await btc.balanceOf(sapAddress),
      sapInitAmount.btc,
      "sap asset 1 amount not right",
    );
    strictEqual(
      await weth.balanceOf(sapAddress),
      sapInitAmount.weth,
      "sap asset 2 amount not right",
    );
    strictEqual(
      await bnb.balanceOf(sapAddress),
      sapInitAmount.bnb,
      "sap asset 3 amount not right",
    );
    strictEqual(
      await sol.balanceOf(sapAddress),
      sapInitAmount.sol,
      "sap asset 4 amount not right",
    );
    strictEqual(
      await sap.balanceOf(owner.address),
      sapInitAmount.sap,
      "sap init amount not right",
    );
  });
  test("should not init twice", async () => {
    const { usdc, btc, weth, bnb, sol, sap, sapInitAmount } = await init();
    const sapAddress = await sap.getAddress();
    await usdc.approve(sapAddress, sapInitAmount.usdc);
    await btc.approve(sapAddress, sapInitAmount.btc);
    await weth.approve(sapAddress, sapInitAmount.weth);
    await bnb.approve(sapAddress, sapInitAmount.bnb);
    await sol.approve(sapAddress, sapInitAmount.sol);
    await assert.rejects(
      sap.init(
        [
          sapInitAmount.usdc,
          sapInitAmount.btc,
          sapInitAmount.weth,
          sapInitAmount.bnb,
          sapInitAmount.sol,
        ],
        sapInitAmount.sap,
      ),
      /Sap: already initialized/,
    );
  });
  test("should be right price", async () => {
    const { usdc, btc, weth, bnb, sol, sap, pyth, pythPriceIds } = await init();
    const decimals = await sap.decimals();
    const address = await sap.getAddress();
    const ids = Object.values(pythPriceIds);
    const contracts = [usdc, btc, weth, bnb, sol];
    let volumn = 0;
    for (let i = 0; i < 5; i++) {
      const assetPrice = await sap.getAssetPrice(i);
      // check assets price
      const pythPrice = await pyth.getPrice(ids[i]);
      strictEqual(
        b2n(assetPrice, decimals),
        b2n(pythPrice[0], -1n * pythPrice[2]),
        `sap asset price ${i} is not right`,
      );
      // calculate volumn
      const assetAmount = await contracts[i].balanceOf(address);
      volumn +=
        b2n(assetAmount, await contracts[i].decimals()) *
        b2n(assetPrice, decimals);
    }
    // check sap price
    const price = await sap.getPrice();
    const totalSupply = await sap.totalSupply();
    const jsPrice = volumn / b2n(totalSupply, decimals);
    assertNumber(jsPrice, b2n(price, decimals), "sap price is not right");
  });
  test("should buy right", async () => {
    const { otherAccount, usdc, sap } = await init();
    const address = await sap.getAddress();
    const priceBeforeBuy = await sap.getPrice();
    const assetPrice = await sap.getAssetPrice(0);
    const assetAmountBeforeBuy = await usdc.balanceOf(address);
    const totalSupplyBeforeBuy = await sap.totalSupply();
    // do buy
    const payAmount = n2b(1, await usdc.decimals());
    const buyAmount = (payAmount * assetPrice) / priceBeforeBuy;
    await usdc.connect(otherAccount).approve(await sap.getAddress(), payAmount);
    await sap.connect(otherAccount).buy(payAmount, await usdc.getAddress());
    // check
    const amountAfterBuy = await sap.balanceOf(otherAccount.address);
    strictEqual(amountAfterBuy, buyAmount, "sap amount after buy is not right");
    const assetAmountAfterBuy = await usdc.balanceOf(address);
    strictEqual(
      assetAmountAfterBuy,
      assetAmountBeforeBuy + payAmount,
      "sap asset amount after buy is not right",
    );
    const totalSupplyAfterBuy = await sap.totalSupply();
    strictEqual(
      totalSupplyAfterBuy,
      totalSupplyBeforeBuy + buyAmount,
      "sap total supply after buy is not right",
    );
  });
  test("shoul sell right", async () => {
    const { otherAccount, usdc, sap } = await init();
    const address = await sap.getAddress();
    // do buy
    const payAmount = n2b(1, await usdc.decimals());
    await usdc.connect(otherAccount).approve(await sap.getAddress(), payAmount);
    await sap.connect(otherAccount).buy(payAmount, await usdc.getAddress());
    // get values before sell
    const priceBeforeSell = await sap.getPrice();
    const assetPrice = await sap.getAssetPrice(0);
    const assetAmountBeforeSell = await usdc.balanceOf(address);
    const totalSupplyBeforeSell = await sap.totalSupply();
    // do sell
    const sellAmount = await sap.balanceOf(otherAccount.address);
    const receiveAmount = (sellAmount * priceBeforeSell) / assetPrice;
    await sap.connect(otherAccount).sell(sellAmount, await usdc.getAddress());
    // check
    const amountAfterSell = await sap.balanceOf(otherAccount.address);
    strictEqual(amountAfterSell, 0n, "sap amount after sell is not right");
    const assetAmountAfterSell = await usdc.balanceOf(address);
    strictEqual(
      assetAmountAfterSell,
      assetAmountBeforeSell - receiveAmount,
      "sap asset amount after sell is not right",
    );
    const totalSupplyAfterSell = await sap.totalSupply();
    strictEqual(
      totalSupplyAfterSell,
      totalSupplyBeforeSell - sellAmount,
      "sap total supply after sell is not right",
    );
  });
});
