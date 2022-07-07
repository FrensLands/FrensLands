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

  let M01CF: StarknetContractFactory;
  let M01_Contract: StarknetContract;
  let accountArbitrer: Account, account1: Account;

  const M01_CONTRACT =
    "0x01c025dba9b67047f5b84b09255517e878e9a21d45334638c867f150ce02ab51";

  const M01_CONTRACT_DEV =
    "0x003fdf42da5cf22eeeb9d50d0659f003f111087692095d46f8eaff028c09720d";

  // Add tableaux à remplir pour testing purposes

  // ---------  FETCH ACCOUNT TO USE ON STARKNET-DEVNET  ---------
  before(async function () {
    console.log("Started fetching accounts");

    accountArbitrer = await starknet.getAccountFromAddress(
      process.env.ADDRESS_DEV as string,
      process.env.PRIVATE_KEY_DEV as string,
      "OpenZeppelin"
    );

    // accountArbitrer = await starknet.getAccountFromAddress(
    //   process.env.ADDRESS as string,
    //   process.env.PRIVATE_KEY as string,
    //   "OpenZeppelin"
    // );
    // console.log("Arbitrer account : ", accountArbitrer.address);
  });

  it("Deploy M01 contract ", async function () {
    // Deploy M03 Maps Contract
    M01CF = await starknet.getContractFactory("M01_Worlds");
    M01_Contract = await M01CF.deploy();
    // M03_Contract = M03CF.getContractAt(M03_CONTRACT_DEV);
    console.log("M01 contract", M01_Contract.address);
  });

  it("Fill Map array", async function () {
    // Build line
    const line: string[] = [];
    var i = 0;
    while (i < 640) {
      line[i] = "1234501890123456";
      i++;
    }
    console.log("array to initialize", line);

    await accountArbitrer.invoke(
      M01_Contract,
      "fill_map_array",
      {
        tokenId: { low: 1, high: 0 },
        data: line,
        index: 1,
      }
      //   { maxFee: estimatedFee.amount }
    );

    const { data: data_array } = await accountArbitrer.call(
      M01_Contract,
      "get_map_array",
      {
        tokenId: { high: 0, low: 1 },
      }
    );
    console.log("Data on Map array ", data_array);
  });

  it("Check can build", async function () {
    const { bool: bool1 } = await accountArbitrer.call(
      M01_Contract,
      "_check_can_build",
      {
        tokenId: { high: 0, low: 1 },
        building_size: 4,
        pos_start: 24,
      }
    );
    console.log("Boolean ", bool1);

    const { bool: bool2 } = await accountArbitrer.call(
      M01_Contract,
      "_check_can_build",
      {
        tokenId: { high: 0, low: 1 },
        building_size: 2,
        pos_start: 640,
      }
    );
    console.log("Boolean ", bool2);
  });
});
