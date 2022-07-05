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

  let ERC1155ContractFactory: StarknetContractFactory;
  let ERC1155Contract: StarknetContract;
  let accountArbitrer: Account, account1: Account, account2: Account;

  // ---------  FETCH ACCOUNT TO USE ON STARKNET-DEVNET  ---------
  before(async function () {
    console.log("Started fetching accounts");

    accountArbitrer = await starknet.getAccountFromAddress(
        process.env.ADDRESS_DEV as string,
        process.env.PRIVATE_KEY_DEV as string,
        "OpenZeppelin"
    );
    account1 = await starknet.getAccountFromAddress(
        process.env.ADDRESS_DEV_1 as string,
      process.env.PRIVATE_KEY_DEV_1 as string,
        "OpenZeppelin"
    );
    account2 = await starknet.getAccountFromAddress(
        process.env.ADDRESS_DEV_2 as string,
        process.env.PRIVATE_KEY_DEV_2 as string,
        "OpenZeppelin"
    );

  });

  // ---------  DEPLOY ERC1155 CONTRACT ---------
  it("Deploy ERC1155 and test mint and burn ", async function () {
    // Deploy ERC1155 Contract
    ERC1155ContractFactory = await starknet.getContractFactory(
      "tokens/ERC1155_Mintable_Burnable"
    );
    ERC1155Contract = await ERC1155ContractFactory.deploy({
        uri: starknet.shortStringToBigInt('uri'),
      owner: accountArbitrer.address,
    });
    console.log("ERC1155 address: ", ERC1155Contract.address);

    await accountArbitrer.invoke(
        ERC1155Contract,
        "mintBatch",
        {
            to: account1.address,
            ids: [{high: 0n, low: 1n}],
            amounts: [{high: 0n, low: 5n}],
        }
      );

    const {balance: Oldbalance} = await accountArbitrer.call(ERC1155Contract ,"balanceOf", {account : account1.address, id : {high: 0n, low: 1n} })
    console.log("balance: ", Oldbalance)
    
    expect(Oldbalance).to.deep.equal({ low: 5n, high: 0n });

    await account1.invoke(
        ERC1155Contract,
        "setApprovalForAll",
        {
            operator: accountArbitrer.address,
            approved: 1,
        }
      );

    await accountArbitrer.invoke(
        ERC1155Contract,
        "burnBatch",
        {
            _from: account1.address,
            ids: [{high: 0n, low: 1n}],
            amounts: [{high: 0n, low: 5n}],
        }
      );

    const {balance: Newbalance} = await accountArbitrer.call(ERC1155Contract ,"balanceOf", {account : account1.address, id : {high: 0n, low: 1n} })
    console.log("balance: ", Newbalance)
    expect(Newbalance).to.deep.equal({ low: 0n, high: 0n });

  });

  it("Deploy ERC1155 and test approve ", async function () {

    await accountArbitrer.invoke(
        ERC1155Contract,
        "mintBatch",
        {
            to: account1.address,
            ids: [{high: 0n, low: 1n}],
            amounts: [{high: 0n, low: 5n}],
        }
    );

    const {balance: Oldbalance} = await accountArbitrer.call(ERC1155Contract ,"balanceOf", {account : account1.address, id : {high: 0n, low: 1n} })
    console.log("balance: ", Oldbalance)
    
    expect(Oldbalance).to.deep.equal({ low: 5n, high: 0n });
    
    await account1.invoke(
        ERC1155Contract,
        "setApprovalForAll",
        {
            operator: account2.address,
            approved: 1,
        }
      );

    await accountArbitrer.invoke(
        ERC1155Contract,
        "safeBatchTransferFrom",
        {
            _from : account1.address, 
            to : account2.address, 
            ids: [{high: 0n, low: 1n}],
            amounts: [{high: 0n, low: 2n}],
        }
    );
    const {balance: Newbalance} = await accountArbitrer.call(ERC1155Contract ,"balanceOf", {account : account1.address, id : {high: 0n, low: 1n} })
    console.log("balance account 1: ", Newbalance)
    expect(Newbalance).to.deep.equal({ low: 3n, high: 0n });
    
    const {balance: balance2} = await accountArbitrer.call(ERC1155Contract ,"balanceOf", {account : account2.address, id : {high: 0n, low: 1n} })
    console.log("balance account 2: ", balance2)
    expect(balance2).to.deep.equal({ low: 2n, high: 0n });

    await accountArbitrer.invoke(
        ERC1155Contract,
        "safeBatchTransferFrom",
        {
            _from : account1.address, 
            to : account2.address, 
            ids: [{high: 0n, low: 1n}],
            amounts: [{high: 0n, low: 3n}],
        }
    );
    const {balance: Newbalance1} = await accountArbitrer.call(ERC1155Contract ,"balanceOf", {account : account1.address, id : {high: 0n, low: 1n} })
    console.log("balance account 1: ", Newbalance1)
    expect(Newbalance1).to.deep.equal({ low: 0n, high: 0n });
    
    const {balance: Newbalance2} = await accountArbitrer.call(ERC1155Contract ,"balanceOf", {account : account2.address, id : {high: 0n, low: 1n} })
    console.log("balance account 2: ", Newbalance2)
    expect(Newbalance2).to.deep.equal({ low: 5n, high: 0n });

  });

});
