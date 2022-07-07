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

  let M03CF: StarknetContractFactory;
  let M03_Contract: StarknetContract;
  let accountArbitrer: Account, account1: Account;

  const M03_CONTRACT =
    "0x01c025dba9b67047f5b84b09255517e878e9a21d45334638c867f150ce02ab51";

  const M03_CONTRACT_DEV =
    "0x003fdf42da5cf22eeeb9d50d0659f003f111087692095d46f8eaff028c09720d";

  const buildingTypes = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
    22, 23, 24,
  ];
  const buildingCosts = [
    1,
    "103202",
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
    1,
    10,
    5,
    5,
  ];
  //   ID_ressource, qty_resource, qty_gold, qty_energy
  const dailyCosts = [
    1, 3, 2, 3, 1, 3, 2, 3, 1, 3, 2, 3, 1, 3, 2, 3, 1, 3, 2, 3, 1, 3, 2, 3, 1,
    3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3,
    5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5,
    5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5,
  ];

  const dailyHarvest = [
    1, 3, 2, 3, 1, 3, 2, 3, 1, 3, 2, 3, 1, 3, 2, 3, 1, 3, 2, 3, 1, 3, 2, 3, 1,
    3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3,
    5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5,
    5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5, 1, 3, 5, 5,
  ];

  const buildingPops = [
    2, 5, 2, 5, 2, 5, 2, 5, 2, 5, 2, 5, 2, 5, 2, 5, 2, 5, 2, 5, 2, 5, 2, 5, 2,
    5, 2, 5, 2, 5, 2, 5, 2, 5, 2, 5, 2, 5, 2, 5, 2, 5, 2, 5, 2, 5, 2, 5,
  ];
  // ---------  FETCH ACCOUNT TO USE ON STARKNET-DEVNET  ---------
  before(async function () {
    console.log("Started fetching accounts");

    // accountArbitrer = await starknet.getAccountFromAddress(
    //   process.env.ADDRESS_DEV as string,
    //   process.env.PRIVATE_KEY_DEV as string,
    //   "OpenZeppelin"
    // );

    accountArbitrer = await starknet.getAccountFromAddress(
      process.env.ADDRESS as string,
      process.env.PRIVATE_KEY as string,
      "OpenZeppelin"
    );
    // console.log("Arbitrer account : ", accountArbitrer.address);
  });

  it("Deploy M03 contract ", async function () {
    // Deploy M03 Maps Contract
    M03CF = await starknet.getContractFactory("M03_Buildings");
    M03_Contract = await M03CF.deploy({
      type: buildingTypes,
      level: 1,
      building_cost: buildingCosts,
      daily_cost: dailyCosts,
      daily_harvest: dailyHarvest,
      pop: buildingPops,
    });
    // M03_Contract = M03CF.getContractAt(M03_CONTRACT_DEV);
    console.log("M03 contract", M03_Contract.address);
  });

  it("View fixed data", async function () {
    const { data: data1 } = await accountArbitrer.call(
      M03_Contract,
      "view_fixed_data",
      {
        type: 1,
        level: 1,
      }
    );
    console.log("Data", data1);
  });

  //   it("Test unpack costs", async function () {
  //     const { ret_array } = await accountArbitrer.call(
  //       M03_Contract,
  //       "_get_costs_from_chain",
  //       {
  //         nb_resources: 2,
  //         resources_qty: "110205",
  //       }
  //     );
  //     console.log("Data", ret_array);
  //   });

  it("Build building & destroy building", async function () {
    //     const { count: before } = await accountArbitrer.call(
    //       M03_Contract,
    //       "get_building_count",
    //       {
    //         token_id: { low: 1, high: 0 },
    //       }
    //     );
    //     console.log("count", before);
    //     const { res: cost } = await accountArbitrer.call(
    //       M03_Contract,
    //       "get_upgrade_cost",
    //       {
    //         building_type: 1,
    //         level: 1,
    //       }
    //     );
    //     console.log("cost", cost);
    //   const estimatedFee = await accountArbitrer.estimateFee(
    //     M03_Contract,
    //     "upgrade",
    //     {
    //       token_id: { low: 1, high: 0 },
    //       building_id: 2,
    //       level: 1,
    //       position: 1,
    //       allocated_population: 2,
    //     }
    //   );
    //   expectFeeEstimationStructure(estimatedFee);
    // await accountArbitrer.invoke(
    //   M03_Contract,
    //   "upgrade",
    //   {
    //     token_id: { low: 1, high: 0 },
    //     building_type_id: 2,
    //     level: 1,
    //     position: 1,
    //     allocated_population: 2,
    //   }
    //   //   { maxFee: estimatedFee.amount }
    // );
    // const { count: after } = await accountArbitrer.call(
    //   M03_Contract,
    //   "get_building_count",
    //   {
    //     token_id: { low: 1, high: 0 },
    //   }
    // );
    // console.log("after count", after);
    // const { data: data1 } = await accountArbitrer.call(
    //   M03_Contract,
    //   "get_all_building_ids",
    //   {
    //     token_id: { low: 1, high: 0 },
    //   }
    // );
    // console.log("All building dat", data1);
    // await accountArbitrer.invoke(M03_Contract, "upgrade", {
    //   token_id: { low: 1, high: 0 },
    //   building_type_id: 3,
    //   level: 1,
    //   position: 1,
    //   allocated_population: 2,
    // });
    // const { data: data2 } = await accountArbitrer.call(
    //   M03_Contract,
    //   "get_all_building_ids",
    //   {
    //     token_id: { low: 1, high: 0 },
    //   }
    // );
    // console.log("All building dat 2", data2);
    //     await accountArbitrer.invoke(M03_Contract, "destroy", {
    //       token_id: { low: 1, high: 0 },
    //       building_unique_id: 1,
    //     });
    //     const { data } = await accountArbitrer.call(
    //       M03_Contract,
    //       "get_all_building_ids",
    //       {
    //         token_id: { low: 1, high: 0 },
    //       }
    //     );
    //     console.log("All building data after destroy", data);
  });
});
