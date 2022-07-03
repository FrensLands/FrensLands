import hardhat from "hardhat";
import { starknet } from "hardhat";

async function main() {
  const account = await starknet.deployAccount("OpenZeppelin");

  console.log("Account: ", account.address);
  console.log("Private Key: ", account.privateKey);
  console.log("Public Key: ", account.publicKey);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
