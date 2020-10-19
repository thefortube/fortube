const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');

// Import utilities from Test Helpers
const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const Bank = contract.fromArtifact('Bank');
const MockUSDT = contract.fromArtifact('MockUSDT');
const InterestRateModel = contract.fromArtifact('InterestRateModel');
const MSign = contract.fromArtifact('MSign');
const BankController = contract.fromArtifact('BankController');
const FUSDT = contract.fromArtifact('FUSDT');
const PriceOracles = contract.fromArtifact('PriceOracles');
const MockOracle = contract.fromArtifact('MockOracle');
const MockETHChainLink = contract.fromArtifact('MockETHChainLink');

describe('Bank', function () {
  const [owner, other] = accounts;

  // Use large integers ('big numbers')
  const value = new BN('10');

  // 每个测试执行前执行
  beforeEach(async function () {
    // 设置底层预言机
    this.mockOracle = await MockOracle.new({ from: owner });
    // 设置 mock usdt
    this.usdt = await MockUSDT.new({ from: owner });
    // 设置 usdt 价格，hardcode
    await this.mockOracle.set(this.usdt.address, new BN('1004000000000000000'), { from: owner });

    this.mockETHChainLink = await MockETHChainLink.new({ from: owner });

    // 设置预言机并设置底层预言机
    this.oracle = await PriceOracles.new({ from: owner });
    await this.oracle.setOracle(this.mockOracle.address, { from: owner });
    await this.oracle.setEthToUsdPrice(this.mockETHChainLink.address, { from: owner });

    // 设置利率模型
    this.irm = await InterestRateModel.new(new BN('20000000000000000'), new BN('500000000000000000'), { from: owner });
    // 设置多签
    this.mSign = await MSign.new(new BN('1'), [owner], { from: owner });
    // 设置 controller
    this.controller = await BankController.new({ from: owner });
    await this.controller.initialize(this.mSign.address, { from: owner })
    await this.controller.setOracle(this.oracle.address, { from: owner });
    // 设置 bank
    this.bank = await Bank.new({ from: owner });
    await this.bank.initialize(this.controller.address, this.mSign.address, { from: owner });
    // 设置 fusdt
    this.fUSDT = await FUSDT.new({ from: owner });
    await this.fUSDT.initialize(
      new BN('20000'),
      this.controller.address,
      this.irm.address,
      this.usdt.address,
      this.bank.address,
      new BN('1000000000000000000'),
      "fUSDT",
      "fUSDT",
      18,
      { from: owner });

    await this.controller.setBankEntryAddress(this.bank.address, { from: owner });
    await this.controller.setTheForceToken(this.usdt.address, { from: owner });

    // 授权
    await this.usdt.approve(this.controller.address, this.usdt.address, { from: owner });
    await this.controller._supportMarket(
      this.fUSDT.address,
      new BN('800000000000000000'),
      new BN('1050000000000000000'),
      { from: owner });

  });

  // 测试
  it('deposit', async function () {
    // 第一次存钱
    await this.bank.deposit(this.usdt.address, new BN('111111'), { from: owner });
    // 查询 controller 余额
    const balance = await this.controller.getCashPrior(this.usdt.address, { from: owner });
    console.log(balance.toString());
    // 查询 exchange rate
    console.log("----exchange rate----")
    const exchangeRate = await this.fUSDT.exchangeRateStored({ from: owner });
    console.log(exchangeRate.toString());
    // 查询 totalSupply
    console.log("----totalsupply----");
    console.log((await this.fUSDT.totalSupply()).toString());
    // 第二次存钱
    await this.bank.deposit(this.usdt.address, new BN('111111'), { from: owner });
    const balance2 = await this.controller.getCashPrior(this.usdt.address, { from: owner });
    console.log(balance2.toString());
    // 第二次查询 exchange rate
    console.log("----exchange rate----")
    const exchangeRate2 = await this.fUSDT.exchangeRateStored({ from: owner });
    console.log(exchangeRate2.toString());
    // 第二次查询余额
    console.log("----balanceof---")
    const balanceOf = await this.fUSDT.balanceOf(owner, { from: owner })
    console.log(balanceOf.toString());

    const tokens = await this.fUSDT.accountTokens(owner);
    console.log(tokens.toString());
    console.log("----totalsupply----");
    console.log((await this.fUSDT.totalSupply()).toString());
    // 取款
    const a = await this.bank.withdraw(this.usdt.address, new BN('1'));

    // 借款
    await this.bank.borrow(this.usdt.address, 1000000);
    // 还款
    await this.bank.repay(this.usdt.address, 1000000);


  });

  it('cashInAndOut', async function () {

    await this.bank.cashIn(this.usdt.address, 10);

    await this.bank.cashOut(this.usdt.address, 10);

  });

  // 测试事件
  // it('deposit emits an event', async function () {
  //   const receipt = await this.contract.deposit(value, { from: owner, value: value });

  //   // Test that a ValueChanged event was emitted with the new value
  //   expectEvent(receipt, 'Deposit', { addr: owner, amount: value, balance: value });
  // });

  // // 测试回退
  // it('msg.value not equal to the value', async function () {
  //   // Test a transaction reverts
  //   await expectRevert(
  //     this.contract.deposit(value, { from: other, value: value - 1 }),
  //     'value should be equal to msg.value'
  //   );
  // });
});