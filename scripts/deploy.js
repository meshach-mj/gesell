const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  
  console.log("Deploying Gesell with account:", deployer.address);
  console.log("Account balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString());

  const USDC_ADDRESS = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
  const MINT_PRICE = 37_070_000;
  const FEE_RECIPIENT = deployer.address;

  console.log("\nDeployment parameters:");
  console.log("- USDC Address:", USDC_ADDRESS);
  console.log("- Mint Price:", MINT_PRICE, "(37.07 USDC per GSLL)");
  console.log("- Fee Recipient:", FEE_RECIPIENT);

  const Gesell = await hre.ethers.getContractFactory("Gesell");
  const gesell = await Gesell.deploy(USDC_ADDRESS, MINT_PRICE, FEE_RECIPIENT);

  await gesell.waitForDeployment();

  const address = await gesell.getAddress();
  console.log("\n✅ Gesell deployed to:", address);
  
  return address;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
