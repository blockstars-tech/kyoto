const { COYOTE_TEAM_ADDRESS } = process.env;

if (!COYOTE_TEAM_ADDRESS) {
  throw new Error('Team address must be provided, check your env file');
}

module.exports = [
  COYOTE_TEAM_ADDRESS,
  COYOTE_TEAM_ADDRESS,
  COYOTE_TEAM_ADDRESS,
];
