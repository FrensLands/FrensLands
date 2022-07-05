import { expect } from "chai";
import { starknet } from "hardhat";
import {
  StarknetContract,
  StarknetContractFactory,
  Account,
} from "hardhat/types/runtime";
import { ensureEnvVar, expectFeeEstimationStructure } from "./utils/util";

describe("Starknet", function () {
  this.timeout(900_000);

  let testCF: StarknetContractFactory;
  let testContract: StarknetContract;
  let accountArbitrer: Account, account1: Account;

  // ---------  FETCH ACCOUNT TO USE ON STARKNET-DEVNET  ---------
  before(async function () {
    console.log("Started fetching accounts");

    accountArbitrer = await starknet.getAccountFromAddress(
      process.env.ADDRESS_DEV as string,
      process.env.PRIVATE_KEY_DEV as string,
      "OpenZeppelin"
    );
    console.log("Arbitrer account : ", accountArbitrer.address);

    // accountArbitrer = await starknet.getAccountFromAddress(
    //   process.env.ADDRESS as string,
    //   process.env.PRIVATE_KEY as string,
    //   "OpenZeppelin"
    // );
    // console.log("Arbitrer account : ", accountArbitrer.address);
  });

  it("Deploy test contract ", async function () {
    // Deploy Minter Maps Contract
    testCF = await starknet.getContractFactory("test");
    testContract = await testCF.deploy({
      tokenId: { low: 1, high: 0 },
      axis_x: 0,
      blocks_x: 40,
      axis_y: 1,
      blocks_y: 16,
    });
    console.log("Test contract", testContract.address);
  });

  it("Fill map types", async function () {
    // Add Maps_ERC721 addr in Minter contract
    const txHash = await accountArbitrer.invoke(
      testContract,
      "fill_block_ground",
      {
        tokenId: { low: 1n, high: 0n },
        _x: 1n,
        _y: 1n,
        _type: 3n,
      }
    );
    // const receipt = await starknet.getTransactionReceipt(txHash);
    // console.log("receipt", receipt);

    const { type } = await accountArbitrer.call(
      testContract,
      "get_block_ground",
      {
        tokenId: { low: 1n, high: 0n },
        _x: 1n,
        _y: 1n,
      }
    );
    console.log("type", type);
    expect(type).to.deep.equal(3n);
  });

  it("Fill map types batch 1 line", async function () {
    // Build line
    const line: Number[] = [];
    var i = 0;
    while (i < 40) {
      line[i] = Math.floor(Math.random() * 3 + 1);
      i++;
    }
    console.log(line);
    // Add Maps_ERC721 addr in Minter contract
    const txHash = await accountArbitrer.invoke(
      testContract,
      "fill_line_ground",
      {
        tokenId: { low: 1n, high: 0n },
        _y: 1n,
        type: line,
      }
    );
    // const receipt = await starknet.getTransactionReceipt(txHash);
    // console.log("receipt", receipt);

    const { type } = await accountArbitrer.call(
      testContract,
      "get_line_ground",
      {
        tokenId: { low: 1n, high: 0n },
        _y: 1n,
      }
    );
    console.log("type", type);
    // expect(type).to.deep.equal(line);
  });

  it("Fill map all lines", async function () {
    // Build array
    const line: any[] = [];
    var i = 0;
    var j = 0;
    var w = 0;
    while (i < 40) {
      j = 0;
      while (j < 16) {
        line[w] = Math.floor(Math.random() * 3 + 1);
        j++;
        w++;
      }
      i++;
    }
    console.log(line);

    const estimatedFee = await accountArbitrer.estimateFee(
      testContract,
      "fill_all_ground",
      {
        tokenId: { low: 1, high: 0 },
        type: line,
      }
    );
    expectFeeEstimationStructure(estimatedFee);

    // Add Maps_ERC721 addr in Minter contract
    console.log("timestamp start invoke", Date.now());
    const txHash = await accountArbitrer.invoke(
      testContract,
      "fill_all_ground",
      {
        tokenId: { low: 1, high: 0 },
        type: line,
      },
      { maxFee: estimatedFee.amount }
    );
    console.log("timestamp end invoke", Date.now());
    const { type } = await accountArbitrer.call(
      testContract,
      "get_all_ground",
      {
        tokenId: { low: 1, high: 0 },
      }
    );
    console.log("timestamp fetch", Date.now());
    console.log("type", type);
  });
});
