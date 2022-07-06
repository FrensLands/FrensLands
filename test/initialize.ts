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
    MCContractFactory: StarknetContractFactory,
    MapsER721ContractFactory: StarknetContractFactory,
    S_MapsER721ContractFactory: StarknetContractFactory,
    ERC1155ContractFactory: StarknetContractFactory,
    MinterMapsER721ContractFactory: StarknetContractFactory,
    M01ContractFactory: StarknetContractFactory,
    M02ContractFactory: StarknetContractFactory,
    M03ContractFactory: StarknetContractFactory,
    GoldContractFactory: StarknetContractFactory;
  let ArbitrerContract: StarknetContract,
    MCContract: StarknetContract,
    MapsERC721Contract: StarknetContract,
    S_MapsERC721Contract: StarknetContract,
    MinterMapsER721Contract: StarknetContract,
    ERC1155Contract: StarknetContract,
    M01Contract: StarknetContract,
    M02Contract: StarknetContract,
    M03Contract: StarknetContract,
    GoldContract: StarknetContract;
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
    account1 = await starknet.getAccountFromAddress(
      process.env.ADDRESS_DEV_2 as string,
      process.env.PRIVATE_KEY_DEV_2 as string,
      "OpenZeppelin"
    );
    console.log("Account 1 :  ", account1.address);
  });

  // ---------  DEPLOY EXTERNAL CONTRACTS & MODULES CONTRACTS  ---------
  it("Deploy Maps_ERC721 and minter ", async function () {
    // Deploy Minter Maps Contract
    MinterMapsER721ContractFactory = await starknet.getContractFactory(
      "tokens/Minter_Maps_ERC721"
    );
    MinterMapsER721Contract = await MinterMapsER721ContractFactory.deploy({
      admin: accountArbitrer.address,
    });
    console.log("Minter maps", MinterMapsER721Contract.address);

    // Deploy Maps_ERC721 Contract
    MapsER721ContractFactory = await starknet.getContractFactory(
      "tokens/Maps_ERC721_enumerable_mintable_burnable"
    );
    MapsERC721Contract = await MapsER721ContractFactory.deploy({
      name: starknet.shortStringToBigInt("Maps"),
      symbol: starknet.shortStringToBigInt("MAPS"),
      owner: MinterMapsER721Contract.address,
      tokenURI: [
        starknet.shortStringToBigInt("ipfs://faeljfalifhail"),
        starknet.shortStringToBigInt("hdiahdihfjebfjlabfljaflaflajf"),
      ],
    });
    console.log("Maps ERC721 contract deployed at", MapsERC721Contract.address);

    // Deploy M01 module contract
    M01ContractFactory = await starknet.getContractFactory("M01_Worlds");
    M01Contract = await M01ContractFactory.deploy();
    console.log("M01 contract deployed at", M01Contract.address);
    // Deploy M01 module contract
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

    // Deploy S_Maps_ERC721 Contract
    S_MapsER721ContractFactory = await starknet.getContractFactory(
      "tokens/S_Maps_ERC721_mintable_burnable"
    );
    S_MapsERC721Contract = await S_MapsER721ContractFactory.deploy({
      name: starknet.shortStringToBigInt("S_Maps"),
      symbol: starknet.shortStringToBigInt("SMAPS"),
      owner: M01Contract.address,
    });
    console.log(
      "S_Maps ERC721 contract deployed at",
      S_MapsERC721Contract.address
    );

    // Deploy ERC1155 Contract
    ERC1155ContractFactory = await starknet.getContractFactory(
      "tokens/ERC1155_Mintable_Burnable"
    );
    ERC1155Contract = await ERC1155ContractFactory.deploy({
      uri: starknet.shortStringToBigInt("resources_uri"),
      owner: M01Contract.address,
    });
    console.log("ERC1155 address: ", ERC1155Contract.address);

    // Deploy Gold ERC20 contract
    GoldContractFactory = await starknet.getContractFactory(
      "tokens/Gold_ERC20_Mintable_Burnable"
    );
    GoldContract = await GoldContractFactory.deploy({
      name: starknet.shortStringToBigInt("Gold"),
      symbol: starknet.shortStringToBigInt("GG"),
      decimals: 18,
      initial_supply: { low: 0, high: 0 },
      recipient: M01Contract.address,
      owner: M01Contract.address,
    });
    console.log("Gold ERC20 contract ", GoldContract.address);
  });

  // ---------  DEPLOY MODULE CONTROLLER AND ARBITRER CONTRACTS  ---------
  it("Deploy and initialize Arbitrer and ModuleController", async function () {
    // Deploy Arbitrer contract
    ArbitrerContractFactory = await starknet.getContractFactory("Arbitrer");
    ArbitrerContract = await ArbitrerContractFactory.deploy({
      owner_address: accountArbitrer.address,
    });
    console.log("Arbitrer contract deployed at", ArbitrerContract.address);

    // Deploy ModuleController contract
    MCContractFactory = await starknet.getContractFactory("ModuleController");
    MCContract = await MCContractFactory.deploy({
      arbitrer_address: ArbitrerContract.address,
      _maps_address: MapsERC721Contract.address,
      _minter_maps_address: MinterMapsER721Contract.address,
      _s_maps_address: S_MapsERC721Contract.address,
      _gold_address: GoldContract.address,
      _resources_address: ERC1155Contract.address,
    });
    console.log("ModuleController contract deployed at", MCContract.address);

    // Save address of controller into Arbitrer contract
    const txHash = await accountArbitrer.invoke(
      ArbitrerContract,
      "set_address_of_controller",
      {
        contract_address: MCContract.address,
      }
    );
    // Check ModuleController has the right arbitrer initialized
    const { arbitrer_addr: arbitrerAddr } = await accountArbitrer.call(
      MCContract,
      "get_arbitrer"
    );
    expect(arbitrerAddr).to.deep.equal(BigInt(ArbitrerContract.address));

    // Initialize Modules in MC through Arbitrer contract
    await accountArbitrer.invoke(
      ArbitrerContract,
      "batch_set_controller_addresses",
      {
        m01_addr: M01Contract.address,
        m02_addr: M02Contract.address,
        m03_addr: M03Contract.address,
      }
    );

    // Initialize M01 module with controller address
    await accountArbitrer.invoke(M01Contract, "initializer", {
      address_of_controller: MCContract.address,
    });
  });

  it("Initialize Minter contract & Mint NFTs", async function () {
    //
    // Add Maps_ERC721 addr in Minter contract
    await accountArbitrer.invoke(
      MinterMapsER721Contract,
      "set_maps_erc721_address",
      {
        contract_address: MapsERC721Contract.address,
      }
    );
    const { contract_address } = await accountArbitrer.call(
      MinterMapsER721Contract,
      "get_maps_erc721_address"
    );
    expect(contract_address).to.deep.equal(BigInt(MapsERC721Contract.address));

    // Set approval for all & Mint Batch of NFTs
    await accountArbitrer.invoke(
      MinterMapsER721Contract,
      "set_maps_erc721_approval",
      {
        operator: M01Contract.address,
        approved: 1,
      }
    );

    // Mint Batch of NFTs
    await accountArbitrer.invoke(MinterMapsER721Contract, "mint_all", {
      nb: 10,
      token_id: { low: 1, high: 0 },
    });

    const { totalSupply } = await accountArbitrer.call(
      MapsERC721Contract,
      "totalSupply"
    );
    console.log("totalSupply", totalSupply);
    expect(totalSupply).to.deep.equal({ low: 10n, high: 0n });

    const { balance } = await accountArbitrer.call(
      MapsERC721Contract,
      "balanceOf",
      { owner: MinterMapsER721Contract.address }
    );
    console.log("balance of Arbitrer", balance);
  });

  it("Transfer NFT to player from M01 contract", async function () {
    // Call get_map in M01 controller
    await account1.invoke(M01Contract, "get_map", {
      tokenId: { low: 1, high: 0 },
    });

    // Check account 1 is owner of tokenId = (1, 0)
    const { owner } = await accountArbitrer.call(
      MapsERC721Contract,
      "ownerOf",
      { tokenId: { low: 1, high: 0 } }
    );
    expect("0x" + BigInt(owner).toString(16)).to.deep.equal(account1.address);

    // Check account1 can't mint a second map
    try {
      await account1.invoke(M01Contract, "get_map", {
        tokenId: { low: 2, high: 0 },
      });
      expect.fail("Account1 has already minted a map");
    } catch (err: any) {
      //   expect(err.message).to.equal("Maps ERC721: caller is not the admin.");
    }
  });

  it("Start new game", async function () {
    // Account1 needs to set approval first
    await account1.invoke(MapsERC721Contract, "setApprovalForAll", {
      operator: M01Contract.address,
      approved: 1,
    });

    // Call start game
    await account1.invoke(M01Contract, "start_game", {
      tokenId: { low: 1, high: 0 },
    });
    const { owner: ownerMaps } = await account1.call(
      MapsERC721Contract,
      "ownerOf",
      {
        tokenId: { low: 1, high: 0 },
      }
    );
    console.log(
      "owner of NFT is now ",
      BigInt("0x" + BigInt(ownerMaps).toString(16))
    );
    // expect("0x" + BigInt(owner).toString(16)).to.deep.equal(
    //   M01Contract.address
    // );
    const { owner: ownerS_Maps } = await account1.call(
      S_MapsERC721Contract,
      "ownerOf",
      {
        tokenId: { low: 1, high: 0 },
      }
    );
    console.log(
      "owner of NFT is now ",
      "0x" + BigInt(ownerS_Maps).toString(16)
    );

    const { balance: goldBalance } = await account1.call(
      GoldContract,
      "balanceOf",
      { account: account1.address }
    );
    console.log("goldBalance", goldBalance);
    // expect(goldBalance).to.deep.equal(900n);
  });

  // it("Fills the table", async function () {});
});
