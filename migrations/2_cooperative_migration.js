const Web3 = require("web3");
const DaiContractAddress = "0x95b58a6bff3d14b7db2f5cb5f0ad413dc2940658";
const GroupsContract = artifacts.require("Groups");
const TreasuryContract = artifacts.require("Treasury");
const ClientRecordContract = artifacts.require("ClientRecord");
const SavingsConfigContract = artifacts.require("SavingsConfig");
const VenusAdapter = artifacts.require("VenusAdapter");
const VenusLendingService = artifacts.require("VenusLendingService");
const RewardConfigContract = artifacts.require("RewardConfig");
const XendTokenContract = artifacts.require("XendToken");
const EsusuServiceContract = artifacts.require("EsusuService");
const CycleContract = artifacts.require("Cycles")
const busdAddress = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56"
const vbusdAddress = "0x95c78222B3D6e262426483D42CfA53685A67Ab9D"
const EsusuAdapterContract = artifacts.require('EsusuAdapter');
const EsusuAdapterWithdrawalDelegateContract = artifacts.require('EsusuAdapterWithdrawalDelegate');
const EsusuStorageContract = artifacts.require('EsusuStorage');
const XendFinanceGroup = artifacts.require("XendFinanceGroup_Yearn_V1.sol");
const RewardBridgeContract = artifacts.require('RewardBridge');

// const web3 = new Web3("HTTP://127.0.0.1:8545");
// const daiContract = new web3.eth.Contract(DaiContractABI, DaiContractAddress);

module.exports = function (deployer) {
  deployer.then(async () => {
    await deployer.deploy(GroupsContract);

    console.log("GroupsContract address: " + GroupsContract.address);

    await deployer.deploy(CycleContract);

    console.log("CycleContract address: " + CycleContract.address);

    await deployer.deploy(TreasuryContract);

    console.log("TreasuryContract address: " + TreasuryContract.address);

    await deployer.deploy(ClientRecordContract);

    console.log("ClientRecordContract address", ClientRecordContract.address);

    await deployer.deploy(SavingsConfigContract);

    console.log("Savings config address", SavingsConfigContract.address);

    await deployer.deploy(EsusuServiceContract);

    console.log(
      "EsusuServiceContract address: " + EsusuServiceContract.address
    );

    await deployer.deploy(
      RewardConfigContract,
      EsusuServiceContract.address,
      GroupsContract.address
    );

    console.log(
      "RewardConfigContract address: " + RewardConfigContract.address
    );

    await deployer.deploy(XendTokenContract, "Xend Token", "$XEND", "18", "200000000000000000000000000")

    console.log("Xend Token Contract address", XendTokenContract.address);


    await deployer.deploy(RewardBridgeContract, XendTokenContract.address);
    console.log("Reward Bridge Contract address", RewardBridgeContract.address);

    await deployer.deploy(VenusLendingService);
    console.log(
      "venusLendingService Contract address: " + VenusLendingService.address
    );

    await deployer.deploy(
      VenusAdapter,
      VenusLendingService.address
    );

    console.log(
      "VenusAdapter address: " + VenusAdapter.address
    );




    await deployer.deploy(EsusuStorageContract);

    //  address payable serviceContract, address esusuStorageContract, address esusuAdapterContract,
    //                 string memory feeRuleKey, address treasuryContract, address rewardConfigContract, address xendTokenContract

     await deployer.deploy(EsusuAdapterContract,
                            EsusuServiceContract.address,
                            GroupsContract.address,
                            EsusuStorageContract.address);

      await deployer.deploy(EsusuAdapterWithdrawalDelegateContract,
                              EsusuServiceContract.address,
                              EsusuStorageContract.address,
                              EsusuAdapterContract.address,
                              "esusufee",
                              TreasuryContract.address,
                              RewardConfigContract.address,
                              XendTokenContract.address,
                              SavingsConfigContract.address);


    await deployer.deploy(
        XendFinanceGroup,
        VenusLendingService.address,
        busdAddress,
        GroupsContract.address,
        CycleContract.address,
        TreasuryContract.address,
        SavingsConfigContract.address,
        RewardConfigContract.address,
        XendTokenContract.address,
        vbusdAddress
      );

      console.log("XendFinance Group contract : " + XendFinanceGroup.address )
    
    let savingsConfigContract = null
    let venusLendingService = null;
    let rewardConfigContract = null;
    let xendTokenContract = null;
    let cyclesContract = null;
    let groupsContract = null;
    let esusuAdapterContract = null;
    let esusuAdapterWithdrawalDelegateContract = null;
    let esusuStorageContract = null;
    let xendGroup  = null;

    savingsConfigContract = await SavingsConfigContract.deployed();
    venusLendingService = await VenusLendingService.deployed();
    rewardConfigContract = await RewardConfigContract.deployed();
    xendTokenContract = await XendTokenContract.deployed();
    cyclesContract = await CycleContract.deployed();
    esusuAdapterWithdrawalDelegateContract = await EsusuAdapterWithdrawalDelegateContract.deployed();
    esusuStorageContract = await EsusuStorageContract.deployed();
    esusuAdapterContract = await EsusuAdapterContract.deployed();
    groupsContract = await GroupsContract.deployed();
    xendGroup = await XendFinanceGroup.deployed();

   
   

    
  });
};
