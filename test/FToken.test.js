const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');

// Import utilities from Test Helpers
const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const FToken = contract.fromArtifact('FToken');
const BankController = contract.fromArtifact('BankController');
const InterestRateModel = contract.fromArtifact('InterestRateModel');

describe('FToken', function () {
    const [owner, other] = accounts;

    //   // Use large integers ('big numbers')
    //   const value = new BN('10');

    // 每个测试执行前执行
    beforeEach(async function () {
        // init ftoken
        this.contract = await FToken.new({ from: owner });
        // init interest rate model
        this.irmContract = await InterestRateModel.new(
            new BN('20000000000000000'),
            new BN('100000000000000000'),
            { from: owner }
        );
        // init controller
        this.controllerContract = await BankController.new({ from: owner });
        await this.contract.initialize(
            new BN('2000000000000000000'),
            this.irmContract.address,
            '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            'fETH',
            'fETH',
            18,
            { from: owner }
        );
        await this.controllerContract._supportMarket(
            this.contract.address,
            { from: owner });
        await this.contract.setController(this.controllerContract.address);
        // await this.contract._setInterestRateModel(this.irmContract.address);
    });

    it('exchangeRateStored', async function () {
        const exchangeRate = await this.contract.exchangeRateStored(
            new BN('2000000000000000000'),
            { from: owner });
        console.log(exchangeRate.toString());

        // // Use large integer comparisons
        // expect(await this.contract.balance(owner)).to.be.bignumber.equal(value);
    });

    it('_setReserveFactorFresh', async function () {
        await this.contract._setReserveFactorFresh(
            new BN('200000000000000000'),
            { from: owner }
        );
        const reserverFactor = await this.contract.reserveFactor(
            { from: owner }
        );
        // console.log(reserverFactor.toString());
    });

    it('accrueInterest', async function () {
        const transferValue = new BN('10000000000000000000'); // 10*e18
        // // const underlying = await this.fTokenContract.underlying();
        const underlying = '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'
        await this.controllerContract.transferIn(
            owner,
            underlying,
            transferValue,
            { from: owner, value: transferValue });

        await this.contract.accrueInterest(
            new BN('2000000000000000000'),
            { from: owner }
        );
    });

    it('mint', async function () {
        // const transferValue = new BN('10000000000000000000'); // 10*e18
        // // // const underlying = await this.fTokenContract.underlying();
        // const underlying = '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'
        // await this.controllerContract.transferIn(
        //     owner,
        //     underlying,
        //     transferValue,
        //     { from: owner, value: transferValue });

        const deposit = new BN('2000000000000000000');
        await this.contract.mint(
            '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            deposit,
            { from: owner, value: deposit }
        );
    });
});
