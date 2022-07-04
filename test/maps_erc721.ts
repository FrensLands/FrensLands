import { expect } from "chai";
import { starknet } from "hardhat";
import { shortString } from "starknet";
import { BigNumber } from "ethers";
import {
  StarknetContract,
  StarknetContractFactory,
  Account,
} from "hardhat/types/runtime";

describe("Starknet", function () {
  this.timeout(900_000);

  let MapsER721ContractFactory: StarknetContractFactory,
    MinterMapsER721ContractFactory: StarknetContractFactory;
  let MapsERC721Contract: StarknetContract,
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

    // accountArbitrer = await starknet.getAccountFromAddress(
    //   process.env.ADDRESS as string,
    //   process.env.PRIVATE_KEY as string,
    //   "OpenZeppelin"
    // );
    // console.log("Arbitrer account : ", accountArbitrer.address);
    // account1 = await starknet.getAccountFromAddress(
    //   process.env.ADDRESS_2 as string,
    //   process.env.PRIVATE_KEY_2 as string,
    //   "OpenZeppelin"
    // );
    // console.log("Account 1 :  ", account1.address);
  });

  // ---------  DEPLOY MAPS ERC721 CONTRACT AND MINTER  ---------
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
      name: starknet.shortStringToBigInt("test_name"),
      symbol: starknet.shortStringToBigInt("TT"),
      owner: MinterMapsER721Contract.address,
      tokenURI: [
        starknet.shortStringToBigInt("ipfs://faeljfalifhail"),
        starknet.shortStringToBigInt("hdiahdihfjebfjlabfljaflaflajf"),
      ],
    });
    console.log("Maps ERC721 contract deployed at", MapsERC721Contract.address);
  });

  it("Initialize Minter contract & Mint NFTs", async function () {
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

    const { tokenURI } = await accountArbitrer.call(
      MapsERC721Contract,
      "tokenURI",
      { tokenId: { low: 1, high: 0 } }
    );
    console.log("tokenURI is", tokenURI);
    console.log("tokenURI 1", starknet.bigIntToShortString(tokenURI[0]));
    console.log("tokenURI 2", starknet.bigIntToShortString(tokenURI[1]));
  });

  it("These tests should fail", async function () {
    try {
      await account1.invoke(MinterMapsER721Contract, "mint_all", {
        nb: 10,
        token_id: { low: 10, high: 0 },
      });
      expect.fail("Should have because account1 is not admin");
    } catch (err: any) {
      //   expect(err.message).to.equal("Maps ERC721: caller is not the admin.");
    }
  });
});

// Check another account cannot mint ERC721
// Check que depuis le module 01 on peut mint de nouveaux ERC721, les burn, les transférer
