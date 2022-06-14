const REToken = artifacts.require("REToken");
const Marketplace = artifacts.require("Marketplace");
const DAI = artifacts.require("DAI");

module.exports = async function (deployer) {
    await deployer.deploy(REToken);
    const token = await REToken.deployed();
    await deployer.deploy(DAI)
    const dai = await DAI.deployed()
    await deployer.deploy(Marketplace, token.address, dai.address);
};