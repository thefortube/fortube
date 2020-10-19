const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');

// Import utilities from Test Helpers
const { BN, expectEvent, expectRevert, balance } = require('@openzeppelin/test-helpers');

const BankController = contract.fromArtifact('BankController');
const FToken = contract.fromArtifact('FToken');
const InterestRateModel = contract.fromArtifact('InterestRateModel');

// WARNING: Seems there's no better way to test private and internal
// functions, so we'll have to modify them to PUBLIC before testing.
describe('BankController', function () {
    const [owner, other] = accounts;

    // Use large integers ('big numbers')
    // const value = new BN('10');

    // 每个测试执行前执行
    beforeEach(async function () {
        this.contract = await BankController.new({ from: owner });
        this.fTokenContract = await FToken.new({ from: owner });
        this.irmContract = await InterestRateModel.new(
            new BN('20000000000000000'),
            new BN('100000000000000000'),
            { from: owner }
        );
        await this.fTokenContract.initialize(
            new BN('2000000000000000000'),
            this.irmContract.address,
            '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            'fUSDT',
            'fUSDT',
            8,
            { from: owner }
        );
        await this.contract._supportMarket(
            this.fTokenContract.address,
            { from: owner });
        await this.fTokenContract.setController(this.contract.address);
    });

    // 测试
    it('addToMarketInternal', async function () {
        await this.contract.addToMarketInternal(
            this.fTokenContract.address,
            '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            { from: owner });

        const accAsset = await this.contract.accountAssets(
            '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            0,
            { from: owner }
        );
        console.log(accAsset);
        // // Use large integer comparisons
        // expect(await this.contract.balance(owner)).to.be.bignumber.equal(value);
    });

    it('_addMarketInternal', async function () {
        // await this.contract._addMarketInternal(
        //     this.fTokenContract.address,
        //     { from: owner });
        var number = 1;
        // for (var i = 0; i < number; ++i) {
        //     const fTokenx = await FToken.new({ from: owner });
        //     await this.contract._addMarketInternal(
        //         '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        //         fTokenx.address,
        //         { from: owner });
        // }

        // const marketLength = await this.contract.getAllMarkets();
        // console.log(marketLength.length);

        // // Use large integer comparisons
        // expect(marketLength.length).to.be.bignumber.equal(number.toString());
    });

    it('_supportMarket', async function () {
        // await this.contract._supportMarket(
        //     this.fTokenContract.address,
        //     { from: owner });

        // const marketLength = await this.contract.getAllMarkets();
        // console.log(marketLength.length);
        // console.log(marketLength);
        // const underlying = await this.fTokenContract.underlying();
        // console.log("underlying is " + underlying);
        // const market = await this.contract.markets(underlying)
        // console.log(market);

        // // Use large integer comparisons
        // expect(marketLength.length).to.be.bignumber.equal(number.toString());
    });

    it('getFTokeAddress', async function () {
        // await this.contract._supportMarket(
        //     this.fTokenContract.address,
        //     { from: owner });
        const underlying = await this.fTokenContract.underlying();
        const ftokenAddress = await this.contract.getFTokeAddress(
            underlying,
            { from: owner }
        );

        // console.log("ftokenAddress is " + ftokenAddress);

        // // Use large integer comparisons
        // expect(marketLength.length).to.be.bignumber.equal(number.toString());
    });

    it('transferIn', async function () {
        // const contractBalance = await balance.current(this.contract.address);
        // const ownerBalance = await balance.current(owner);
        // console.log('-------before-------');
        // console.log(contractBalance.toString());
        // console.log(ownerBalance.toString());
        const transferValue = new BN('10000000000000000000'); // 10*e18
        // // const underlying = await this.fTokenContract.underlying();
        const underlying = '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'
        await this.contract.transferIn(
            owner,
            underlying,
            transferValue,
            { from: owner, value: transferValue });
        // console.log('-------after-------');
        // const contractBalance2 = await balance.current(this.contract.address);
        // const ownerBalance2 = await balance.current(owner);
        // console.log(contractBalance2.toString());
        // console.log(ownerBalance2.toString());
    });

    it('transferToUser', async function () {
        // const contractBalance = await balance.current(this.contract.address);
        // const ownerBalance = await balance.current(owner);
        // console.log('-------before-transferIn-------');
        // console.log(contractBalance.toString());
        // console.log(ownerBalance.toString());
        const transferValue = new BN('10000000000000000000'); // 10*e18
        const transferValue2 = new BN('5000000000000000000');
        // // const underlying = await this.fTokenContract.underlying();
        const underlying = '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'
        await this.contract.transferIn(
            owner,
            underlying,
            transferValue,
            { from: owner, value: transferValue });
        // console.log('-------after-transferIn-------');
        // const contractBalance2 = await balance.current(this.contract.address);
        // const ownerBalance2 = await balance.current(owner);
        // console.log(contractBalance2.toString());
        // console.log(ownerBalance2.toString());

        // console.log('-------before-transferToUser-------');
        await this.contract.transferToUser(
            underlying,
            owner,
            transferValue2,
            { from: owner });
        // const contractBalance3 = await balance.current(this.contract.address);
        // const ownerBalance3 = await balance.current(owner);
        // console.log(contractBalance3.toString());
        // console.log(ownerBalance3.toString());
        // console.log('-------after-transferToUser-------');
    });

    it('mintCheck', async function () {
        await this.contract.mintCheck(
            '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            owner,
            { from: owner });
    });

    it('getCashPrior', async function () {
        const underlying = '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        const transferValue = new BN('10000000000000000000'); // 10*e18
        // // const underlying = await this.fTokenContract.underlying();
        await this.contract.transferIn(
            owner,
            underlying,
            transferValue,
            { from: owner, value: transferValue });

        const cashPrior = await this.contract.getCashPrior(
            underlying,
            new BN('3000000000000000000'),
            { from: owner });
        console.log(cashPrior.toString());

        // // Use large integer comparisons
        // expect(await this.contract.balance(owner)).to.be.bignumber.equal(value);
    });

    it('_setCollateralFactor', async function () {
        const underlying = '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        // // const underlying = await this.fTokenContract.underlying();
        await this.contract._setCollateralFactor(
            underlying,
            new BN('310000000000000000'),
            { from: owner });
        const newCF = await this.contract.markets(
            '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            { from: owner }
        );

        console.log(newCF.collateralFactor.toString());

        // // Use large integer comparisons
        // expect(await this.contract.balance(owner)).to.be.bignumber.equal(value);
    });

    // WARNING: SET solid price before testing
    it('getAccountLiquidityInternal', async function () {
        // const underlying = '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        // const transferValue = new BN('10000000000000000000'); // 10*e18
        // // // const underlying = await this.fTokenContract.underlying();
        // await this.contract.transferIn(
        //     owner,
        //     underlying,
        //     transferValue,
        //     { from: owner, value: transferValue });
        await this.contract.addToMarketInternal(
            this.fTokenContract.address,
            '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            { from: owner });
        await this.contract._setCollateralFactor(
            '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            new BN('200000000000000000'),
            { from: owner });
        const deposit = new BN('3200000000000000000');
        const er = await this.fTokenContract.exchangeRateStored(0);
        console.log("er is " + er);
        await this.fTokenContract.mint(
            '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            deposit,
            { from: owner, value: deposit }
        );
        // // const underlying = await this.fTokenContract.underlying();
        await this.contract.transferIn(
            owner,
            '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            deposit,
            { from: owner, value: deposit });
        const er2 = await this.fTokenContract.exchangeRateStored(0);
        console.log("er is " + er2);
        // const supply = await this.fTokenContract.totalSupply();
        // console.log("supply is " + supply);
        // const borrows = await this.fTokenContract.totalBorrows();
        // console.log("borrows is " + borrows);
        // const reserves = await this.fTokenContract.totalReserves();
        // console.log("reservers is " + reserves);

        const accountSnapshot = await this.fTokenContract.getAccountState(
            '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            { from: owner }
        );

        // console.log(accountSnapshot[0].toString());
        // console.log(accountSnapshot[1].toString());
        // console.log(accountSnapshot[2].toString());

        const liquidity = await this.contract.getAccountLiquidityInternal(
            '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            this.fTokenContract.address,
            new BN('0'),
            new BN('0'),
            { from: owner });
        console.log(liquidity[0].toString());
        console.log(liquidity[1].toString())

        // // Use large integer comparisons
        // expect(await this.contract.balance(owner)).to.be.bignumber.equal(value);
    });
});