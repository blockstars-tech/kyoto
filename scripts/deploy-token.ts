import { ethers } from 'hardhat';

const { COYOTE_TEAM_ADDRESS } = process.env; // '0x6aBB27cF08D9b2422519f75b1E9e19c94dD3C616';

if (!COYOTE_TEAM_ADDRESS) {
  throw new Error('Team address must be provided, check your env file');
}

const main = async () => {
  const coyoteToken = await ethers.getContractFactory('contracts/Coyote.sol:Coyote');
  const token = await coyoteToken.deploy(
    COYOTE_TEAM_ADDRESS,
    COYOTE_TEAM_ADDRESS,
    COYOTE_TEAM_ADDRESS
  );

  await token.deployed();
  console.log('Coyote token deployed to:', token.address);
};

main()
  .then(() => process.exit(0))
  .catch((err) => console.log(err));

export default {};
