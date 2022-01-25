import {
  CoyoteContract,
  CoyoteInstance,
  UniswapV2Router02Contract,
  UniswapV2Router02Instance,
} from "../typechain";
import BN from "bn.js";

const truffleAssert = require("truffle-assertions");

const CoyoteToken: CoyoteContract = artifacts.require("Coyote");
const UniswapV2Router: UniswapV2Router02Contract =
  artifacts.require("UniswapV2Router02");

const constants = {
  ZERO_ADDRESS: "0x0000000000000000000000000000000000000000",
  MAX_UINT256: new BN("2").pow(new BN("256")).sub(new BN("1")),
  MAX_INT256: new BN("2").pow(new BN("255")).sub(new BN("1")),
  MIN_INT256: new BN("2").pow(new BN("255")).mul(new BN("-1")),
};

contract("CoyoteToken", (accounts) => {
  const [
    ownerAddr,
    teamAddr,
    publicSaleAddr,
    reserveAddr,
    user1Addr,
    user2Addr,
    user3Addr,
  ]: string[] = accounts;

  let decimalMultiplier: BN;
  let feeDecimalMultiplier: BN;

  let coyoteInstance: CoyoteInstance;
  let uniswapInstance: UniswapV2Router02Instance;
  let _uniswapRouterAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";

  let value: BN;

  beforeEach("Contract Deployment", async () => {
    coyoteInstance = await CoyoteToken.new(
      teamAddr,
      publicSaleAddr,
      reserveAddr,
      { from: ownerAddr }
    );

    uniswapInstance = await UniswapV2Router.at(_uniswapRouterAddress);

    const _decimals = await coyoteInstance.decimals({ from: ownerAddr });
    decimalMultiplier = new BN(10).pow(_decimals);

    const _feeDecimals = await coyoteInstance.FEE_DECIMALS();
    feeDecimalMultiplier = new BN(10).pow(_feeDecimals);

    value = new BN(1).mul(decimalMultiplier); // 1 Token

    // await coyoteInstance.transfer(user1Addr, new BN(100000).mul(value), {
    //     from: ownerAddr,
    // });
  });

  describe("Constructor", async () => {
    describe("Name and Symbol", async () => {
      it("should return right token NAME", async () => {
        const expected = "Coyote";
        const actual = await coyoteInstance.name({ from: user1Addr });

        assert.equal(actual, expected);
      });

      it("should return right token SYMBOL", async () => {
        const expected = "YOTE";
        const actual = await coyoteInstance.symbol({ from: user1Addr });

        assert.equal(actual, expected);
      });
    });

    describe("Initial Balance Checks", async () => {
      it("should return right TEAM balance", async () => {
        const expected = new BN(187500000000000).mul(decimalMultiplier);
        const actual = await coyoteInstance.balanceOf(teamAddr, {
          from: teamAddr,
        });
        assert.isTrue(actual.eq(expected));
      });

      it("should return right PUBLIC_SALE balance", async () => {
        const expected = new BN(787500000000000).mul(decimalMultiplier);
        const actual = await coyoteInstance.balanceOf(publicSaleAddr, {
          from: publicSaleAddr,
        });

        assert.isTrue(actual.eq(expected));
      });

      it("should return right RESERVE balance", async () => {
        const expected = new BN(250000000000000).mul(decimalMultiplier);
        const actual = await coyoteInstance.balanceOf(reserveAddr, {
          from: reserveAddr,
        });

        assert.isTrue(actual.eq(expected));
      });

      it("should return right DEX_LIQUIDITY balance", async () => {
        const expected = new BN("25000000000000").mul(decimalMultiplier);
        const actual = await coyoteInstance.balanceOf(ownerAddr, {
          from: reserveAddr,
        });

        assert.isTrue(actual.eq(expected));
      });

      it("should return right TOTALSUPPLY balance", async () => {
        const expected = new BN(1250000000000000).mul(decimalMultiplier);
        const actual = await coyoteInstance.totalSupply({
          from: user1Addr,
        });

        assert.isTrue(actual.eq(expected));
      });
    });

    describe("Inital volume check", async () => {
      it("should return right PREVIOUS_VOLUME amount", async () => {
        const expected = new BN(25000000000000).mul(decimalMultiplier);
        const actual = await coyoteInstance.getPreviousVolume({
          from: user1Addr,
        });

        assert.isTrue(actual.eq(expected));
      });
    });

    describe("Initial FEES check", async () => {
      it("should return right BURN_FEE percent", async () => {
        const expected = new BN(3).mul(feeDecimalMultiplier);
        const actual = await coyoteInstance._burnFee();

        assert.isTrue(actual.eq(expected));
      });
      it("should return right SWAP_FEE percent", async () => {
        const expected = new BN(25).mul(feeDecimalMultiplier).divn(10);
        const actual = await coyoteInstance._swapFee();

        assert.isTrue(actual.eq(expected));
      });
      it("should return right REDISTRIBUTE_FEE percent", async () => {
        const expected = new BN(55).mul(feeDecimalMultiplier).divn(10);
        const actual = await coyoteInstance._redistributeFee();

        assert.isTrue(actual.eq(expected));
      });
    });

    describe("Initial ADDRESSes check", async () => {
      it("should return right TEAM address", async () => {
        const expected = teamAddr;
        const actual = await coyoteInstance.teamAddress({
          from: user1Addr,
        });

        assert.equal(actual, expected);
      });

      it("should return right RESERVE address", async () => {
        const expected = reserveAddr;
        const actual = await coyoteInstance.reserveAddress({
          from: user1Addr,
        });

        assert.equal(actual, expected);
      });

      it("should return right PUBLIC_SALE address", async () => {
        const expected = publicSaleAddr;
        const actual = await coyoteInstance.publicSaleAddress({
          from: user1Addr,
        });

        assert.equal(actual, expected);
      });

      it("PancakeswapPair shouldn't be equal to ZERO_ADDRESS", async () => {
        const actual = await coyoteInstance.pancakeswapV2Pair();

        assert.notEqual(actual, constants.ZERO_ADDRESS);
      });

      it("PancakeswapRouter shouldn't be equal to ZERO_ADDRESS", async () => {
        const actual = await coyoteInstance.pancakeswapV2Router();

        assert.notEqual(actual, constants.ZERO_ADDRESS);
      });
    });

    describe("Next Reset Timestamp checks", async () => {
      it("shouldn't be equal to ZERO", async () => {
        const actual = await coyoteInstance.getNextResetTimestamp();

        assert.notEqual(actual, new BN(0));
      });
    });

    describe("SwapAndLiquify status", async () => {
      it("should return true", async () => {
        const actual = await coyoteInstance.swapAndLiquifyEnabled();

        assert.isTrue(actual);
      });
    });
  });

  describe("ERC20", async () => {
    describe("Transfering without fees", async () => {
      let sender = ownerAddr;
      let recipient = user1Addr;

      it("reverts when transferring tokens to the zero address", async function () {
        await truffleAssert.reverts(
          coyoteInstance.transfer(constants.ZERO_ADDRESS, value, {
            from: sender,
          }),
          "ERC20: transfer to the zero address"
        );
      });

      it("emits a Transfer event on successful transfers", async function () {
        const result = await coyoteInstance.transfer(
          recipient,
          value.toString(),
          {
            from: sender,
          }
        );

        truffleAssert.eventEmitted(
          result,
          "Transfer",
          (ev: any) =>
            ev.from === sender &&
            ev.to === recipient &&
            ev.value.toString() === value.toString()
        );
      });

      it("updates balances on successful transfers", async function () {
        const recipientBalanceBefore = await coyoteInstance.balanceOf(
          recipient,
          { from: recipient }
        );
        const senderBalanceBefore = await coyoteInstance.balanceOf(sender, {
          from: sender,
        });
        await coyoteInstance.transfer(recipient, value, {
          from: sender,
        });
        const senderBalanceAfter = await coyoteInstance.balanceOf(sender, {
          from: sender,
        });
        const recipientBalanceAfter = await coyoteInstance.balanceOf(
          recipient,
          {
            from: recipient,
          }
        );

        assert.isTrue(
          recipientBalanceBefore.add(value).eq(recipientBalanceAfter),
          "1"
        );
        assert.isTrue(senderBalanceBefore.sub(value).eq(senderBalanceAfter));
      });
    });

    describe("Transfer with fees", async () => {
      let sender = user1Addr;
      let recipient = user2Addr;
      beforeEach("Approve And Add Liquidity", async () => {
        await coyoteInstance.transfer(
          sender,
          new BN("100000").mul(decimalMultiplier),
          { from: ownerAddr }
        );

        await coyoteInstance.approve(
          _uniswapRouterAddress,
          new BN("100000000").mul(value),
          { from: ownerAddr }
        );
        uniswapInstance.addLiquidityETH(
          coyoteInstance.address,
          new BN("100000000").mul(value),
          0,
          0,
          ownerAddr,
          new BN("7777777777"),
          { from: ownerAddr, value: value }
        );
      });

      it("reverts when transferring tokens to the zero address", async () => {
        await truffleAssert.reverts(
          coyoteInstance.transfer(constants.ZERO_ADDRESS, value, {
            from: sender,
          }),
          "ERC20: transfer to the zero address"
        );
      });

      it("should transfer right amount", async () => {
        const expected = await coyoteInstance.tokenFromReflection(
          await coyoteInstance.reflectionFromToken(
            new BN("100").mul(decimalMultiplier),
            true
          )
        );

        let pairBalanceBefore = await coyoteInstance.balanceOf(
          await coyoteInstance.pancakeswapV2Pair()
        );
        const burnBalanceBefore = await coyoteInstance.balanceOf(
          constants.ZERO_ADDRESS
        );
        const contractBalanceBefore = await coyoteInstance.balanceOf(
          coyoteInstance.address
        );

        await coyoteInstance.approve(
          uniswapInstance.address,
          new BN("100").mul(decimalMultiplier),
          { from: sender }
        );

        const result =
          await uniswapInstance.swapExactTokensForETHSupportingFeeOnTransferTokens(
            new BN("100").mul(decimalMultiplier),
            0,
            [coyoteInstance.address, await uniswapInstance.WETH()],
            sender,
            new BN("77777777777777"),
            { from: sender }
          );

        console.log(result.receipt.rawLogs);

        let pairBalanceAfter = await coyoteInstance.balanceOf(
          await coyoteInstance.pancakeswapV2Pair()
        );

        const burnFeeAmount = new BN(100)
          .mul(decimalMultiplier)
          .muln(3)
          .divn(100);

        const swapFeeAmount = new BN(100)
          .mul(decimalMultiplier)
          .muln(2.5)
          .divn(100);
        const contractBalanceAfter = await coyoteInstance.balanceOf(
          coyoteInstance.address
        );
        const burnBalanceAfter = await coyoteInstance.balanceOf(
          "0x000000000000000000000000000000000000dEaD"
        );

        assert.isTrue(
          contractBalanceAfter.gt(contractBalanceBefore.add(swapFeeAmount))
        );
        assert.isTrue(pairBalanceAfter.gt(pairBalanceBefore.add(expected)));
      });
      it("reverts when transferring 0 tokens", async () => {
        await truffleAssert.reverts(
          coyoteInstance.transfer(recipient, new BN("0"), {
            from: sender,
          }),
          "Transfer amount must be greater than zero"
        );
      });
    });
  });

  describe("Ownable", async () => {
    it("has an owner", async function () {
      const expected = await coyoteInstance.owner({ from: user1Addr });

      assert.equal(ownerAddr, expected);
    });

    describe("transfer ownership", function () {
      it("changes owner after transfer", async function () {
        const receipt = user1Addr;
        const result = await coyoteInstance.transferOwnership(receipt, {
          from: ownerAddr,
        });

        truffleAssert.eventEmitted(result, "OwnershipTransferred", {
          previousOwner: ownerAddr,
          newOwner: receipt,
        });
        const expected = await coyoteInstance.owner({ from: user1Addr });

        assert.equal(receipt, expected);
      });

      it("prevents non-owners from transferring", async function () {
        await truffleAssert.reverts(
          coyoteInstance.transferOwnership(user2Addr, {
            from: user3Addr,
          }),
          "Ownable: caller is not the owner"
        );

        const owner = await coyoteInstance.owner();
      });

      it("guards ownership against stuck state", async function () {
        await truffleAssert.reverts(
          coyoteInstance.transferOwnership(constants.ZERO_ADDRESS, {
            from: ownerAddr,
          }),
          "Ownable: new owner is the zero address"
        );
      });
    });

    describe("renounce ownership", function () {
      it("loses owner after renouncement", async function () {
        const receipt = await coyoteInstance.renounceOwnership({
          from: ownerAddr,
        });
        truffleAssert.eventEmitted(receipt, "OwnershipTransferred");

        const expected = await coyoteInstance.owner({ from: ownerAddr });
        assert.equal(constants.ZERO_ADDRESS, expected);

        it("prevents non-owners from renouncement", async function () {
          await truffleAssert.reverts(
            coyoteInstance.renounceOwnership({ from: user3Addr }),
            "Ownable: caller is not the owner"
          );
        });
      });
    });
  });
});
