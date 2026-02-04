const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  
  console.log("Deploying Gesell with account:", deployer.address);
  console.log("Account balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString());

  // Base mainnet USDC address
  const USDC_ADDRESS = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
  
  // Base Sepolia USDC address (for testing)
  const USDC_SEPOLIA = "0x036CbD53842c5426634e7929541eC2318f3dCF7e";
  
  // Determine which USDC to use based on network
  const network = await hre.ethers.provider.getNetwork();
  const usdcAddress = network.chainId === 8453n ? USDC_ADDRESS : USDC_SEPOLIA;
  
  // Launch mint price: 37.07 USDC per GSLL
  // With 6 decimals: 37.07 * 10^6 = 37,070,000
  const MINT_PRICE = 37_070_000;
  
  // Fee recipient (deployer's address)
  const FEE_RECIPIENT = deployer.address;

  console.log("\nDeployment parameters:");
  console.log("- USDC Address:", usdcAddress);
  console.log("- Mint Price:", MINT_PRICE, "(37.07 USDC per GSLL)");
  console.log("- Fee Recipient:", FEE_RECIPIENT);

  // Deploy the contract
  const Gesell = await hre.ethers.getContractFactory("Gesell");
  const gesell = await Gesell.deploy(usdcAddress, MINT_PRICE, FEE_RECIPIENT);

  await gesell.waitForDeployment();

  const address = await gesell.getAddress();
  console.log("\n✅ Gesell deployed to:", address);
  
  console.log("\nNext steps:");
  console.log("1. Verify the contract on Basescan:");
  console.log(`   npx hardhat verify --network ${network.chainId === 8453n ? 'base' : 'baseSepolia'} ${address} ${usdcAddress} ${MINT_PRICE} ${FEE_RECIPIENT}`);
  console.log("\n2. Test minting:");
  console.log("   - Approve USDC spending for the Gesell contract");
  console.log("   - Call mint() with desired USDC amount");
  
  return address;
}

main()
  .then((address) => {
    console.log("\nDeployment successful!");
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
