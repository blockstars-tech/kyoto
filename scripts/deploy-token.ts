import { ethers } from 'hardhat';

const teamAddress = '0x6aBB27cF08D9b2422519f75b1E9e19c94dD3C616';

const main = async () => {
  const coyoteToken = await ethers.getContractFactory('contracts/Coyote.sol:Coyote');
  const token = await coyoteToken.deploy(
    teamAddress,
    teamAddress,
    teamAddress
  );

  await token.deployed();
  console.log('Coyote token deployed to:', token.address);
};

main()
  .then(() => process.exit(0))
  .catch((err) => console.log(err));

export default {};
