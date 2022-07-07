import { expect } from "chai";
import { starknet } from "hardhat";
import { BigNumber } from "ethers";
import {
  StarknetContract,
  StarknetContractFactory,
  Account,
} from "hardhat/types/runtime";

describe("Starknet", function () {
  this.timeout(900_000);

  let ArbitrerContractFactory: StarknetContractFactory,
    MCContractFactory: StarknetContractFactory;

  let MapsER721ContractFactory: StarknetContractFactory,
    S_MapsER721ContractFactory: StarknetContractFactory,
    ERC1155ContractFactory: StarknetContractFactory,
    MinterMapsER721ContractFactory: StarknetContractFactory,
    GoldContractFactory: StarknetContractFactory;

  let M01ContractFactory: StarknetContractFactory,
    M02ContractFactory: StarknetContractFactory,
    M03ContractFactory: StarknetContractFactory;

  let ArbitrerContract: StarknetContract, MCContract: StarknetContract;

  let MapsERC721Contract: StarknetContract,
    S_MapsERC721Contract: StarknetContract,
    MinterMapsER721Contract: StarknetContract,
    ERC1155Contract: StarknetContract,
    GoldContract: StarknetContract;

  let M01Contract: StarknetContract,
    M02Contract: StarknetContract,
    M03Contract: StarknetContract;

  let accountArbitrer: Account, account1: Account;

  var map_array: string[] = [];

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

  const MINTER =
    "0x068e13c3f34ffd33fec6514356229346025c1f7688f5566a1e869035fa3e8179";
  const MAP =
    "0x06f17c440255ce33a824423191cab7db08a121fc47a3702fb3264b9a5389dca6";
  const M01 =
    "0x00110507f0542b409252c50d02d0be123915f04ac08633bd085d0a748908d57c";
  const M02 = "";
  // ---------  FETCH ACCOUNT TO USE ON STARKNET-DEVNET  ---------
  before(async function () {
    console.log("Started fetching accounts");

    accountArbitrer = await starknet.getAccountFromAddress(
      process.env.ADDRESS_DEV as string,
      process.env.PRIVATE_KEY_DEV as string,
      "OpenZeppelin"
    );
    console.log("Arbitrer account : ", accountArbitrer.address);

    account1 = await starknet.getAccountFromAddress(
      process.env.ADDRESS_DEV_2 as string,
      process.env.PRIVATE_KEY_DEV_2 as string,
      "OpenZeppelin"
    );
    console.log("Account 1 :  ", account1.address);

    // Fill array of positions
    var i = 0;
    var x = 1;
    var y = 1;
    var id: any = "";
    var next_id = 0;
    var zero = "0";
    var health = "99";
    var level = "1";
    var active = "0";
    var qty = "";
    while (i < 640) {
      var pos_x = x < 10 ? "0" + x : x;
      var pos_y = y < 10 ? "0" + y : y;
      var res = "00";
      if (x == 20 && y == 5) {
        res = "01";
        next_id++;
        if (id < 10) id = "00" + next_id;
        if (id > 10 && id < 100) id = "0" + next_id;
      } else if (x % 5 == 0) {
        res = "02";
        next_id++;
        if (id < 10) id = "00" + next_id;
        if (id > 10 && id < 100) id = "0" + next_id;
      } else if (x % 3) {
        res = "03";
        next_id++;
        if (id < 10) id = "00" + next_id;
        if (id > 10 && id < 100) id = "0" + next_id;
      } else {
        id = "000";
      }
      map_array[i] =
        (((pos_x as string) + pos_y) as string) +
        "1" +
        res +
        id +
        health +
        "05" +
        level +
        active;

      if (i % 40 === 0 && i != 0) {
        x = 0;
        y++;
      } else {
        x++;
      }
      i++;
    }
    console.log(map_array);
  });

  // ---------  DEPLOY EXTERNAL CONTRACTS & MODULES CONTRACTS  ---------
  it("Deploy Maps_ERC721 and minter ", async function () {
    // Deploy Minter Maps Contract
    MinterMapsER721ContractFactory = await starknet.getContractFactory(
      "tokens/Minter_Maps_ERC721"
    );
    // MinterMapsER721Contract = await MinterMapsER721ContractFactory.deploy({
    //   admin: accountArbitrer.address,
    // });
    MinterMapsER721Contract =
      MinterMapsER721ContractFactory.getContractAt(MINTER);
    console.log("Minter maps", MinterMapsER721Contract.address);

    // Deploy Maps_ERC721 Contract
    MapsER721ContractFactory = await starknet.getContractFactory(
      "tokens/Maps_ERC721_enumerable_mintable_burnable"
    );
    MapsERC721Contract = MapsER721ContractFactory.getContractAt(MAP);
    // MapsERC721Contract = await MapsER721ContractFactory.deploy({
    //   name: starknet.shortStringToBigInt("Frens Lands"),
    //   symbol: starknet.shortStringToBigInt("FrensLands"),
    //   owner: MinterMapsER721Contract.address,
    //   tokenURI: [
    //     starknet.shortStringToBigInt("ipfs://QmSxbQNFpqRF9q1FC6cAF4bM"),
    //     starknet.shortStringToBigInt("ikEXnGMzNuwzpHxkgvTTrX"),
    //   ],
    // });
    // CID : ipfs://QmSxbQNFpqRF9q1FC6cAF4bMikEXnGMzNuwzpHxkgvTTrX

    console.log("Maps ERC721 contract deployed at", MapsERC721Contract.address);

    // Deploy M01 module contract
    M01ContractFactory = await starknet.getContractFactory("M01_Worlds");
    // M01Contract = await M01ContractFactory.deploy({
    //   tokenId: [
    //     1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    //     21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38,
    //     39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50,
    //   ],
    //   data: map_array,
    // });
    M01Contract = M01ContractFactory.getContractAt(M01);
    console.log("M01 contract deployed at", M01Contract.address);
    // Deploy M02 module contract
    M02ContractFactory = await starknet.getContractFactory("M02_Resources");
    M02Contract = await M02ContractFactory.deploy();
    console.log("M02 contract deployed at", M02Contract.address);
    // Deploy M01 module contract
    M03ContractFactory = await starknet.getContractFactory("M03_Buildings");
    M03Contract = await M03ContractFactory.deploy({
      // type: buildingTypes,
      // level: 1,
      // building_cost: buildingCosts,
      // daily_cost: dailyCosts,
      // daily_harvest: dailyHarvest,
      // pop: buildingPops,
    });
    console.log("M03 contract deployed at", M03Contract.address);

    //   // Deploy S_Maps_ERC721 Contract
    //   S_MapsER721ContractFactory = await starknet.getContractFactory(
    //     "tokens/S_Maps_ERC721_mintable_burnable"
    //   );
    //   S_MapsERC721Contract = await S_MapsER721ContractFactory.deploy({
    //     name: starknet.shortStringToBigInt("S_Maps"),
    //     symbol: starknet.shortStringToBigInt("SMAPS"),
    //     owner: M01Contract.address,
    //   });
    //   console.log(
    //     "S_Maps ERC721 contract deployed at",
    //     S_MapsERC721Contract.address
    //   );

    //   // Deploy ERC1155 Contract
    //   ERC1155ContractFactory = await starknet.getContractFactory(
    //     "tokens/ERC1155_Mintable_Burnable"
    //   );
    //   ERC1155Contract = await ERC1155ContractFactory.deploy({
    //     uri: starknet.shortStringToBigInt("resources_uri"),
    //     owner: M01Contract.address,
    //   });
    //   console.log("ERC1155 address: ", ERC1155Contract.address);

    //   // Deploy Gold ERC20 contract
    //   GoldContractFactory = await starknet.getContractFactory(
    //     "tokens/Gold_ERC20_Mintable_Burnable"
    //   );
    //   GoldContract = await GoldContractFactory.deploy({
    //     name: starknet.shortStringToBigInt("FrensCoin"),
    //     symbol: starknet.shortStringToBigInt("FC"),
    //     decimals: 18,
    //     initial_supply: { low: 0, high: 0 },
    //     recipient: M01Contract.address,
    //     owner: M01Contract.address,
    //   });
    //   console.log("Gold ERC20 contract ", GoldContract.address);
    // });

    // // ---------  DEPLOY MODULE CONTROLLER AND ARBITRER CONTRACTS  ---------
    // it("Deploy and initialize Arbitrer and ModuleController", async function () {
    //   // Deploy Arbitrer contract
    //   ArbitrerContractFactory = await starknet.getContractFactory("Arbitrer");
    //   ArbitrerContract = await ArbitrerContractFactory.deploy({
    //     owner_address: accountArbitrer.address,
    //   });
    //   console.log("Arbitrer contract deployed at", ArbitrerContract.address);

    //   // Deploy ModuleController contract
    //   MCContractFactory = await starknet.getContractFactory("ModuleController");
    //   MCContract = await MCContractFactory.deploy({
    //     arbitrer_address: ArbitrerContract.address,
    //     _maps_address: MapsERC721Contract.address,
    //     _minter_maps_address: MinterMapsER721Contract.address,
    //     _s_maps_address: S_MapsERC721Contract.address,
    //     _gold_address: GoldContract.address,
    //     _resources_address: ERC1155Contract.address,
    //   });
    //   console.log("ModuleController contract deployed at", MCContract.address);

    //   // Save address of controller into Arbitrer contract
    //   const txHash = await accountArbitrer.invoke(
    //     ArbitrerContract,
    //     "set_address_of_controller",
    //     {
    //       contract_address: MCContract.address,
    //     }
    //   );
    //   // Check ModuleController has the right arbitrer initialized
    //   const { arbitrer_addr: arbitrerAddr } = await accountArbitrer.call(
    //     MCContract,
    //     "get_arbitrer"
    //   );
    //   expect(arbitrerAddr).to.deep.equal(BigInt(ArbitrerContract.address));

    //   // Initialize Modules in MC through Arbitrer contract
    //   await accountArbitrer.invoke(
    //     ArbitrerContract,
    //     "batch_set_controller_addresses",
    //     {
    //       m01_addr: M01Contract.address,
    //       m02_addr: M02Contract.address,
    //       m03_addr: M03Contract.address,
    //     }
    //   );

    //   // Initialize Modules with controller address
    //   await accountArbitrer.invoke(M01Contract, "initializer", {
    //     address_of_controller: MCContract.address,
    //   });
    //   await accountArbitrer.invoke(M03Contract, "initializer", {
    //     address_of_controller: MCContract.address,
    //   });
    // });

    // it("Initialize Minter contract & Mint NFTs", async function () {
    //   //
    //   // Add Maps_ERC721 addr in Minter contract
    //   await accountArbitrer.invoke(
    //     MinterMapsER721Contract,
    //     "set_maps_erc721_address",
    //     {
    //       contract_address: MapsERC721Contract.address,
    //     }
    //   );
    //   const { contract_address } = await accountArbitrer.call(
    //     MinterMapsER721Contract,
    //     "get_maps_erc721_address"
    //   );
    //   expect(contract_address).to.deep.equal(BigInt(MapsERC721Contract.address));

    //   // Set approval for all & Mint Batch of NFTs
    //   await accountArbitrer.invoke(
    //     MinterMapsER721Contract,
    //     "set_maps_erc721_approval",
    //     {
    //       operator: M01Contract.address,
    //       approved: 1,
    //     }
    //   );

    //   // Mint Batch of NFTs
    //   await accountArbitrer.invoke(MinterMapsER721Contract, "mint_all", {
    //     nb: 10,
    //     token_id: { low: 1, high: 0 },
    //   });

    //   const { totalSupply } = await accountArbitrer.call(
    //     MapsERC721Contract,
    //     "totalSupply"
    //   );
    //   console.log("totalSupply", totalSupply);
    //   expect(totalSupply).to.deep.equal({ low: 10n, high: 0n });

    //   const { balance } = await accountArbitrer.call(
    //     MapsERC721Contract,
    //     "balanceOf",
    //     { owner: MinterMapsER721Contract.address }
    //   );
    //   console.log("balance of Arbitrer", balance);
    // });

    // it("Transfer NFT to player from M01 contract", async function () {
    //   // Call get_map in M01 controller
    //   await account1.invoke(M01Contract, "get_map", {
    //     tokenId: { low: 1, high: 0 },
    //   });

    //   // Check account 1 is owner of tokenId = (1, 0)
    //   const { owner } = await accountArbitrer.call(
    //     MapsERC721Contract,
    //     "ownerOf",
    //     { tokenId: { low: 1, high: 0 } }
    //   );
    //   expect("0x" + BigInt(owner).toString(16)).to.deep.equal(account1.address);

    //   // Check account1 can't mint a second map
    //   try {
    //     await account1.invoke(M01Contract, "get_map", {
    //       tokenId: { low: 2, high: 0 },
    //     });
    //     expect.fail("Account1 has already minted a map");
    //   } catch (err: any) {
    //     //   expect(err.message).to.equal("Maps ERC721: caller is not the admin.");
    //   }
    // });

    // it("Start new game", async function () {
    //   // Account1 needs to set approval first
    //   await account1.invoke(MapsERC721Contract, "setApprovalForAll", {
    //     operator: M01Contract.address,
    //     approved: 1,
    //   });

    //   // Call start game
    //   await account1.invoke(M01Contract, "start_game", {
    //     tokenId: { low: 1, high: 0 },
    //   });
    //   const { owner: ownerMaps } = await account1.call(
    //     MapsERC721Contract,
    //     "ownerOf",
    //     {
    //       tokenId: { low: 1, high: 0 },
    //     }
    //   );
    //   console.log(
    //     "owner of NFT is now ",
    //     BigInt("0x" + BigInt(ownerMaps).toString(16))
    //   );
    //   // expect("0x" + BigInt(owner).toString(16)).to.deep.equal(
    //   //   M01Contract.address
    //   // );
    //   const { owner: ownerS_Maps } = await account1.call(
    //     S_MapsERC721Contract,
    //     "ownerOf",
    //     {
    //       tokenId: { low: 1, high: 0 },
    //     }
    //   );
    //   console.log(
    //     "owner of NFT is now ",
    //     "0x" + BigInt(ownerS_Maps).toString(16)
    //   );

    //   const { balance: goldBalance } = await account1.call(
    //     GoldContract,
    //     "balanceOf",
    //     { account: account1.address }
    //   );
    //   console.log("goldBalance", goldBalance);
    //   // expect(goldBalance).to.deep.equal(900n);
  });

  // it("Fills the table", async function () {});
});
