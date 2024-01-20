import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { ContractFactory } from "ethers";
import { describe, test } from "mocha";
import assert, { strictEqual } from "node:assert";
import { Sap as SapContract } from "../typechain-types/contracts/Sap";
import { Token as TokenContract } from "../typechain-types/contracts/Token";

// @ts-ignore
import { ethers } from "hardhat";

// all time on chain is in second
const DAY_MULTIPLIER = 24 * 60 * 60;

async function deploy() {
  const [owner, otherAccount] = await ethers.getSigners();
  // token
  const Token: ContractFactory = await ethers.getContractFactory("Token");
  const token = (await Token.deploy("Token", "TKN")) as TokenContract;
  const token2 = (await Token.deploy("Token2", "TK2")) as TokenContract;
  const initAmount = 100n * 10n ** 18n;
  await token.mint(owner.address, initAmount);
  await token.mint(otherAccount.address, initAmount);
  await token2.mint(owner.address, initAmount);
  await token2.mint(otherAccount.address, initAmount);
  // sap
  const Sap: ContractFactory = await ethers.getContractFactory("Sap");
  const pythPriceIds = [
    "0x63f341689d98a12ef60a5cff1d7f85c70a9e17bf1575f0e7c0b2512d48b1c8b3",
    "0x2b9ab1e972a281585084148ba1389800799bd4be63b957507db1349314e47445",
  ];
  const sap = (await Sap.deploy(
    "Sap",
    "SAP",
    "0xa2aa501b19aff244d90cc15a4cf739d2725b5729",
    [await token.getAddress(), await token2.getAddress()],
    pythPriceIds,
  )) as SapContract;
  return {
    owner,
    otherAccount,
    initAmount,
    token,
    token2,
    sap,
    pythPriceIds,
  };
}

describe("deploy test", () => {
  test("should be mint right amount", async () => {
    const { owner, otherAccount, initAmount, token, token2 } =
      await loadFixture(deploy);
    const ownerTokenBalance = await token.balanceOf(owner.address);
    const otherTokenBalance = await token.balanceOf(otherAccount.address);
    strictEqual(ownerTokenBalance.toString(), initAmount.toString());
    strictEqual(otherTokenBalance.toString(), initAmount.toString());
    const ownerTokenBalance2 = await token2.balanceOf(owner.address);
    const otherTokenBalance2 = await token2.balanceOf(otherAccount.address);
    strictEqual(ownerTokenBalance2.toString(), initAmount.toString());
    strictEqual(otherTokenBalance2.toString(), initAmount.toString());
  });
  test("should be right owner", async () => {
    const { owner, sap } = await loadFixture(deploy);
    strictEqual(await sap.owner(), owner.address, "sap owner is not right");
  });
  test("should be right token", async () => {
    const { token, token2, sap } = await loadFixture(deploy);
    strictEqual(
      await token.getAddress(),
      await sap.getAssetToken(0),
      "sap token is not right",
    );
    strictEqual(
      await token2.getAddress(),
      await sap.getAssetToken(1),
      "sap token is not right",
    );
  });
  test("should be right pyth price id", async () => {
    const { pythPriceIds, sap } = await loadFixture(deploy);
    strictEqual(
      pythPriceIds[0],
      await sap.getAssetPriceId(0),
      "sap pyth price id is not right",
    );
    strictEqual(
      pythPriceIds[1],
      await sap.getAssetPriceId(1),
      "sap pyth price id is not right",
    );
  });
});

describe("token test", () => {
  test("should claim right", async () => {
    const { otherAccount, token } = await loadFixture(deploy);
    const claimAmount = await token.getClaimAmount();
    const otherTokenBalance = await token.balanceOf(otherAccount.address);
    await token.connect(otherAccount).claim();
    const otherTokenBalanceAfterClaim = await token.balanceOf(
      otherAccount.address,
    );
    strictEqual(
      otherTokenBalanceAfterClaim.toString(),
      (otherTokenBalance + claimAmount).toString(),
      "token balance is not right after claim",
    );
  });
  test("should not claim before claim time", async () => {
    const { otherAccount, token } = await loadFixture(deploy);
    await token.connect(otherAccount).claim();
    try {
      await token.connect(otherAccount).claim();
      assert(false, "claim before claim time");
    } catch (e) {}
  });
  test("should claim after claim time", async () => {
    const { otherAccount, token } = await loadFixture(deploy);
    await token.connect(otherAccount).claim();
    await time.increase(1 * DAY_MULTIPLIER);
    try {
      await token.connect(otherAccount).claim();
    } catch (e) {
      assert(false, "can not claim after claim time");
    }
  });
});

describe("business test", () => {});
