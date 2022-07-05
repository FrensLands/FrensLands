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

  const A1 = 5
  const A2 = 4
  const A3 = 3
  const A4 = 2
  const A5 = 1

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
    testCF = await starknet.getContractFactory("test2");
    testContract = await testCF.deploy();
    console.log("Test2 contract", testContract.address);
  });


  // it("Test value", async function () {
  //   // Add Maps_ERC721 addr in Minter contract
  //   console.log('timestamp start', Date.now())
  //   const txHash = await accountArbitrer.invoke(
  //     testContract,
  //     "calcul_value",
  //     {
  //       value: 7,
  //       multiplier: A3,
  //     }
  //   );
  //   console.log('timestamp end', Date.now())
  //
  //   const { value } = await accountArbitrer.call(
  //     testContract,
  //     "get_values"
  //   );
  //   console.log("value", value);
  // });

  it("Test value", async function () {
    console.log('timestamp start', Date.now())
    const txHash = await accountArbitrer.invoke(
      testContract,
      "compose",
      {
        bArr: [100000, 10000, 1000, 100, 10],
        values: [0, 4, 9, 2, 1, 0],
      }
    );
    console.log('timestamp end', Date.now())

    const { comp } = await accountArbitrer.call(
      testContract,
      "view_composition",
    );
    console.log("composition", comp);
  });

  // it("Get comp", async function () {
  //   // Add Maps_ERC721 addr in Minter contract
  //   console.log('timestamp start', Date.now())
  //   const txHash = await accountArbitrer.invoke(
  //     testContract,
  //     "add_all"
  //   );
  //   console.log('timestamp end', Date.now())
  //
  //   const { comp } = await accountArbitrer.call(
  //     testContract,
  //     "view_composition",
  //   );
  //   console.log("composition", comp);
  // });

  it("decompose", async function () {
    // Add Maps_ERC721 addr in Minter contract
    console.log('timestamp start', Date.now())
    const txHash = await accountArbitrer.invoke(
      testContract,
      "decompose",
      {
        multArr: [5, 4, 3, 2, 1, 117],
        bArr: [100000, 10000, 1000, 100, 10],
        numChar: 3,
      }
    );
    console.log('timestamp end', Date.now())

    const { res : decomp1 } = await accountArbitrer.call(
      testContract,
      "view_decomp",
      {
        i : 0
      }
    );
    console.log("decomp1", decomp1);

    const { res : decomp2 } = await accountArbitrer.call(
      testContract,
      "view_decomp",
      {
        i : 1
      }
    );
    console.log("decomp2", decomp2);

    const { res : decomp3 } = await accountArbitrer.call(
      testContract,
      "view_decomp",
      {
        i : 2
      }
    );
    console.log("decomp3", decomp3);

    const { res : decomp4 } = await accountArbitrer.call(
      testContract,
      "view_decomp",
      {
        i : 3
      }
    );
    console.log("decomp4", decomp4);

    const { res : decomp5 } = await accountArbitrer.call(
      testContract,
      "view_decomp",
      {
        i : 4
      }
    );
    console.log("decomp5", decomp5);

    const { res : decomp6 } = await accountArbitrer.call(
      testContract,
      "view_decomp",
      {
        i : 5
      }
    );
    console.log("decomp6", decomp6);
  });


});
