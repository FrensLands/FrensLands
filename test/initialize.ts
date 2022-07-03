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
    MinterMapsER721ContractFactory: StarknetContractFactory;
  let ArbitrerContract: StarknetContract,
    MCContract: StarknetContract,
    MapsERC721Contract: StarknetContract,
    MinterMapsER721Contract: StarknetContract;
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

  // ---------  DEPLOY MAPS ERC721 CONTRACT AND MINTER  ---------
  it("Deploy Maps_ERC721 and minter ", async function () {
    // Deploy Minter Maps Contract
    MinterMapsER721ContractFactory = await starknet.getContractFactory(
      "tokens/Maps_ERC721_minter"
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
      name: 1952805748, // "test"
      symbol: 21588, // "TT"
      owner: MinterMapsER721Contract.address,
      tokenURI: [
        "1784348726136159628901492144555",
        "8836189228152314246964477678196",
        "0977025785677824071683945718526",
        "9971642739250023220843052540810",
        "8906",
      ],
    });
    console.log("Maps ERC721 contract deployed at", MapsERC721Contract.address);
  });

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
      arbitrer_address: accountArbitrer.address,
      _maps_address: MapsERC721Contract.address,
      _minter_maps_address: MinterMapsER721Contract.address,
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
    expect(arbitrerAddr).to.deep.equal(BigInt(accountArbitrer.address));
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
        operator: accountArbitrer.address,
        approved: 1,
      }
    );
    // TODO: modifier pour que l'operator soit le contrat 01 et non le MC controller

    // Set approval for all & Mint Batch of NFTs
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
});

// Arbitrer can mint all with uri_token_addr
// Check another account cannot mint ERC721
// Check que depuis le module 01 on peut mint de nouveaux ERC721, les burn, les transférer
