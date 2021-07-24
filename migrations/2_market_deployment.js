const CalvaToken = artifacts.require("CalvaToken");
const Pakos = artifacts.require("Pakos");
const Classifieds = artifacts.require("Classifieds");

module.exports = function (deployer) {
  deployer.deploy(CalvaToken);
  deployer.deploy(Pakos);
  deployer.deploy(Classifieds(CalvaToken, Pakos));
};
