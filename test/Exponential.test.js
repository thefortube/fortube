const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');

// Import utilities from Test Helpers
const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const Exponential = contract.fromArtifact('Exponential');

// WARNING: Seems there's no better way to test private and internal
// functions, so we'll have to modify them to PUBLIC before testing.
describe('Exponential', function () {
    const [owner, other] = accounts;

    // // Use large integers ('big numbers')
    // const value = new BN('10');

    // execute before every test
    beforeEach(async function () {
        this.contract = await Exponential.new({ from: owner });
    });

    it('getExp', async function () {
        const res = await this.contract.getExp(
            new BN('2000000000000000000'),
            new BN('1000000000000000000'),
            { from: owner }
        );
        console.log(res.toString());

        // Use large integer comparisons
        expect(res).to.be.bignumber.equal((2 * 1e18).toString());
    });

    it('addExp', async function () {
        const res = await this.contract.addExp(
            new BN('2000000000000000000'),
            new BN('1000000000000000000'),
            { from: owner }
        );
        console.log(res.toString());

        //   // Use large integer comparisons
        expect(res).to.be.bignumber.equal((3 * 1e18).toString());
    });

    it('subExp', async function () {
        const res = await this.contract.subExp(
            new BN('3000000000000000000'),
            new BN('1500000000000000000'),
            { from: owner }
        );
        console.log(res.toString());

        //   // Use large integer comparisons
        expect(res).to.be.bignumber.equal((1.5 * 1e18).toString());
    });

    it('mulExp', async function () {
        const res = await this.contract.mulExp(
            new BN('10'),
            new BN('1000007762969811699'),
            { from: owner }
        );
        console.log(res.toString());

        //   // Use large integer comparisons
        // expect(res).to.be.bignumber.equal((4.8 * 1e18).toString());
    });

    // it('mulExpBackUp', async function () {
    //     const res = await this.contract.mulExpBackUp(
    //         new BN('10'),
    //         new BN('1000007762969811699'),
    //         { from: owner }
    //     );
    //     console.log(res.toString());

    //     //   // Use large integer comparisons
    //     // expect(res).to.be.bignumber.equal((4.8 * 1e18).toString());
    // });

    it('divExp', async function () {
        const res = await this.contract.divExp(
            new BN('10'),
            new BN('1000007762969811699'),
            { from: owner }
        );
        console.log(res.toString());

        //   // Use large integer comparisons
        // expect(res).to.be.bignumber.equal((1.875 * 1e18).toString());
    });

    // it('divExpBackUp', async function () {
    //     const res = await this.contract.divExpBackUp(
    //         new BN('10'),
    //         new BN('1000007762969811699'),
    //         { from: owner }
    //     );
    //     console.log(res.toString());

    //     //   // Use large integer comparisons
    //     // expect(res).to.be.bignumber.equal((1.875 * 1e18).toString());
    // });

    it('mulExp3', async function () {
        const res = await this.contract.mulExp3(
            new BN('1050000000000000000'),
            new BN('20000'),
            new BN('1000000000000000000'),
            { from: owner }
        );
        console.log(res.toString());

        //   // Use large integer comparisons
        // expect(res).to.be.bignumber.equal((7.2 * 1e18).toString());
    });

    it('mulScalar', async function () {
        const res = await this.contract.mulScalar(
            new BN('3000000000000000000'),
            new BN('1000000000000000000'),
            { from: owner }
        );
        console.log(res.toString());

        //   // Use large integer comparisons
        // expect(res).to.be.bignumber.equal((new BN(3 * 1e36)).toString());
        // expect(res).to.eq.BN(new BN(3 * 1e36))
    });

    it('mulScalarTruncate', async function () {
        const res = await this.contract.mulScalarTruncate(
            new BN('3000000000000000000'),
            new BN('1230000000000000000'),
            // { from: owner }
        );
        console.log(res.toString());

        //   // Use large integer comparisons
        expect(res).to.be.bignumber.equal((3.69 * 1e18).toString());
    });

    it('mulScalarTruncateAddUInt', async function () {
        const res = await this.contract.mulScalarTruncateAddUInt(
            new BN('21000'),
            new BN('61700000000000000000000'),
            new BN('0'),
            // { from: owner }
        );
        console.log(res.toString());

        //   // Use large integer comparisons
        expect(res).to.be.bignumber.equal((5.69 * 1e18).toString());
    });

    it('divScalarByExpTruncate', async function () {
        const res = await this.contract.divScalarByExpTruncate(
            new BN('2000000000000000000'),
            new BN('2000000000000000000'),
            // { from: owner }
        );
        console.log(res.toString());

        //   // Use large integer comparisons
        // expect(res).to.be.bignumber.equal((5.69 * 1e18).toString());
    });

    it('divScalarByExp', async function () {
        const res = await this.contract.divScalarByExp(
            new BN('3000000000000000000'),
            new BN('1230000000000000000'),
            // { from: owner }
        );
        console.log(res.toString());

        //   // Use large integer comparisons
        // expect(res).to.be.bignumber.equal((5.69 * 1e18).toString());
    });

    it('divScalar', async function () {
        const res = await this.contract.divScalar(
            new BN('3000000000000000000'),
            new BN('1230000000000000000'),
            // { from: owner }
        );
        console.log(res.toString());

        //   // Use large integer comparisons
        // expect(res).to.be.bignumber.equal((5.69 * 1e18).toString());
    });

    it('truncate', async function () {
        const res = await this.contract.truncate(
            new BN('1230000000000000000'),
            // { from: owner }
        );
        console.log(res.toString());

        //   // Use large integer comparisons
        // expect(res).to.be.bignumber.equal((5.69 * 1e18).toString());
    });

    it('test', async function () {
        const res = await this.contract.addExp(
            new BN('1600000000000000000'),
            new BN('0'),
            // { from: owner }
        );
        console.log(res.toString());
        const res2 = await this.contract.subExp(
            new BN('1600000000000000000'),
            new BN('0'),
            // { from: owner }
        );
        console.log(res2.toString());

        //   // Use large integer comparisons
        // expect(res).to.be.bignumber.equal((5.69 * 1e18).toString());
    });



});