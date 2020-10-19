const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');

// Import utilities from Test Helpers
const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const InterestRateModel = contract.fromArtifact('InterestRateModel');

describe('FToken', function () {
    const [owner, other] = accounts;

    //   // Use large integers ('big numbers')
    //   const value = new BN('10');

    // 每个测试执行前执行
    beforeEach(async function () {
        this.contract = await InterestRateModel.new(
            new BN('20000000000000000'),
            new BN('100000000000000000'),
            { from: owner }
        );
        // await this.controllerContract._supportMarket(
        //     this.contract.address,
        //     { from: owner });
        // await this.contract.setController(this.controllerContract.address);
    });

    it('utilizationRate', async function () {
        const uR = await this.contract.utilizationRate(
            new BN('213000000000000000000'),
            new BN('2300000000000000000'),
            new BN('2000000000000000000'),
            { from: owner });
        console.log(uR.toString());
    });

    it('getBorrowRate', async function () {
        const bR = await this.contract.getBorrowRate(
            new BN('213000000000000000000'),
            new BN('2300000000000000000'),
            new BN('2000000000000000000'),
            { from: owner });
        console.log(bR.toString());
    });

    it('getSupplyRate', async function () {
        const bR = await this.contract.getSupplyRate(
            new BN('213000000000000000000'),
            new BN('2300000000000000000'),
            new BN('2000000000000000000'),
            new BN('20000000000000000'),
            { from: owner });
        console.log(bR.toString());
    });



});