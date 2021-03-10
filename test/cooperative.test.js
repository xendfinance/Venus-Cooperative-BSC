const { assert, group } = require("console");
const { send } = require("process");

const Web3 = require("web3");

const web3 = new Web3("HTTP://127.0.0.1:8545");

const GroupsContract = artifacts.require("Groups");

const CycleContract = artifacts.require("Cycles");

const XendFinanceGroup = artifacts.require("XendFinanceGroup_Yearn_V1.sol");

const ClientRecordContract = artifacts.require("ClientRecord");

const SavingsConfigContract = artifacts.require("SavingsConfig");

const VenusAdapter = artifacts.require("VenusAdapter");
const VenusLendingService = artifacts.require("VenusLendingService");

const RewardConfigContract = artifacts.require("RewardConfig");

const XendTokenContract = artifacts.require("XendToken");

const DaiContractABI = require("./abi/DaiContract.json");

const busdAddress = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56";

const daiContract = new web3.eth.Contract(DaiContractABI, busdAddress);

const unlockedAddress = "0x631fc1ea2270e98fbd9d92658ece0f5a269aa161";

//  Approve a smart contract address or normal address to spend on behalf of the owner
async function approveDai(spender, owner, amount) {
  await daiContract.methods.approve(spender, amount).send({ from: owner });

  console.log(
    `Address ${spender}  has been approved to spend ${amount} x 10^-18 Dai by Owner:  ${owner}`
  );
}

//  Send Dai from our constant unlocked address to any recipient
async function sendDai(amount, recipient) {
  var amountToSend = BigInt(amount); //  1000 Dai

  console.log(`Sending  ${amountToSend} x 10^-18 Dai to  ${recipient}`);

  await daiContract.methods
    .transfer(recipient, amountToSend)
    .send({ from: unlockedAddress });

  let recipientBalance = await daiContract.methods.balanceOf(recipient).call();

  console.log(`Recipient: ${recipient} DAI Balance: ${recipientBalance}`);
}
var account1;
var account2;
var account3;

var account1Balance;
var account2Balance;
var account3Balance;

contract("XendFinanceGroup_Yearn_v1", () => {
  let contractInstance = null;
  let savingsConfigContract = null;
  let xendTokenContract = null;
  let venusLendingService = null;
  let rewardConfigContract = null;
  let venusAdapter = null;
  let xendGroupsContract = null;
  let cycleContract = null;
  let groupsContract = null;

  before(async () => {
    savingsConfigContract = await SavingsConfigContract.deployed();
    xendTokenContract = await XendTokenContract.deployed();
    venusLendingService = await VenusLendingService.deployed();
    clientRecordContract = await ClientRecordContract.deployed();
    rewardConfigContract = await RewardConfigContract.deployed();
    venusAdapter = await VenusAdapter.deployed();
    cycleContract = await CycleContract.deployed();
    groupsContract = await GroupsContract.deployed();
    xendGroupsContract = await XendFinanceGroup.deployed();

    await savingsConfigContract.createRule(
      "XEND_FINANCE_COMMISION_DIVISOR",
      0,
      0,
      100,
      1
    );

    await savingsConfigContract.createRule(
      "XEND_FINANCE_COMMISION_DIVIDEND",
      0,
      0,
      1,
      1
    );

    await savingsConfigContract.createRule(
      "PERCENTAGE_PAYOUT_TO_USERS",
      0,
      0,
      0,
      1
    );

    await savingsConfigContract.createRule("PERCENTAGE_AS_PENALTY", 0, 0, 1, 1);

    await cycleContract.activateStorageOracle(XendFinanceGroup.address);

    await groupsContract.activateStorageOracle(XendFinanceGroup.address);

    await xendGroupsContract.setAdapterAddress();

    console.log("set adapter address");

    await xendGroupsContract.setGroupCreatorRewardPercent("100");

    //0. update fortube adapter
    await venusLendingService.updateAdapter(VenusAdapter.address);

    //12.
    await rewardConfigContract.SetRewardParams(
      "100000000000000000000000000",
      "10000000000000000000000000",
      "2",
      "7",
      "10",
      "15",
      "4",
      "60",
      "4"
    );

    //13.
    await rewardConfigContract.SetRewardActive(false);

    //  Get the addresses and Balances of at least 2 accounts to be used in the test
    //  Send DAI to the addresses
    web3.eth.getAccounts().then(function (accounts) {
      account1 = accounts[0];
      account2 = accounts[1];
      account3 = accounts[2];

      //  send money from the unlocked dai address to accounts 1 and 2
      var amountToSend = BigInt(2000000000000000000); //   10,000 Dai

      //  get the eth balance of the accounts
      web3.eth.getBalance(account1, function (err, result) {
        if (err) {
          console.log(err);
        } else {
          account1Balance = web3.utils.fromWei(result, "ether");
          console.log(
            "Account 1: " +
              accounts[0] +
              "  Balance: " +
              account1Balance +
              " ETH"
          );
        }
      });

      web3.eth.getBalance(account2, function (err, result) {
        if (err) {
          console.log(err);
        } else {
          account2Balance = web3.utils.fromWei(result, "ether");
          console.log(
            "Account 2: " +
              accounts[1] +
              "  Balance: " +
              account2Balance +
              " ETH"
          );
        }
      });
    });
  });

  it("Should deploy the Xend Finance Group smart contracts", async () => {
    console.log(xendGroupsContract.address, "contract address");
    assert(xendGroupsContract.address !== "");
  });

  it("Should create a group with account 1", async () => {
    await xendGroupsContract.createGroup("Njoku Master", "NJ");

    let groupInfo = await xendGroupsContract.getGroupById("1");

    //assert(BigInt(groupInfo[0].exists) == true);
  });

  it("should create a cycle and join with account one and two", async () => {
    let duration = "1";
    let startTimeStamp = "2";
    let groupId = "1";
    let maximumSlots = "2";
    let hasMaximumSlots = false;
    let cycleStakeAmount = BigInt(100000000000000000000);
    let cycleResult = await xendGroupsContract.createCycle(
      groupId,
      startTimeStamp,
      duration,
      maximumSlots,
      hasMaximumSlots,
      cycleStakeAmount
    );
    assert(cycleResult.receipt.status == true);
    //console.log(cycleResult.receipt.status, "cycle result");

    /** joining cycle event */
    let approvedAmount = BigInt(100000000000000000000);

    await sendDai(approvedAmount, account1);

    await sendDai(approvedAmount, account2);

    await approveDai(xendGroupsContract.address, account1, approvedAmount);

    await approveDai(xendGroupsContract.address, account2, approvedAmount);

    //await xendGroupsContract.setAdapterAddress();

    await xendGroupsContract.joinCycle("1", "1", { from: account1 });

    await xendGroupsContract.joinCycle("1", "1", { from: account2 });

    let result = await cycleContract.getCycleInfoById("1");

    console.log(
      `cycle id: ${BigInt(result[0])}`,
      `grouop id:  ${BigInt(result[1])}`,
      `number of depositors:  ${BigInt(result[2])}`,
      `cycle start time:  ${BigInt(result[3])}`,
      `cycle duration:  ${BigInt(result[4])}`,
      `maximum slots:  ${BigInt(result[5])}`,
      ` has maximum slots:  ${BigInt(result[6])}`,
      `cycle stake amount:  ${BigInt(result[7])}`,
      `total stakes:  ${BigInt(result[8])}`,
      `stake claimed:  ${BigInt(result[9])}`,
      `cycle status:  ${BigInt(result[10])}`,
      `stakes claimed before maturity:  ${BigInt(result[11])}`,
      "cycle info"
    );
  });

  it("should start a cycle and the first member should withdraw from cycle", async () => {
    await xendGroupsContract.activateCycle("1");

    //const pricePerFullShare = await venusAdapter.GetPricePerFullShare();
    const waitTime = (seconds) =>
      new Promise((resolve) => setTimeout(resolve, seconds * 1000));

    await waitTime(20);

    console.log(waitTime, "waiting time");

    let balanceBeforeWithdrawal = await daiContract.methods
    .balanceOf(account1)
    .call();

  console.log(
    `Recipient: ${account1} DAI Balance before withdrawal: ${balanceBeforeWithdrawal}`
  );


    await xendGroupsContract.withdrawFromCycle("1");

    let cycleInfoResult = await cycleContract.getCycleInfoById("1");

    // let cycleMemberIndex = await cycleContract.getCycleMemberIndex(BigInt(cycleInfoResult[0]), account1);

    let balanceAfterWithdrawal = await daiContract.methods
    .balanceOf(account1)
    .call();

  console.log(
    `Recipient: ${account1} DAI Balance after withdrawal: ${balanceAfterWithdrawal}`
  );

assert(balanceAfterWithdrawal > balanceBeforeWithdrawal)
    

    console.log(
      `cycle id: ${BigInt(cycleInfoResult[0])}`,
      `grouop id:  ${BigInt(cycleInfoResult[1])}`,
      `number of depositors:  ${BigInt(cycleInfoResult[2])}`,
      `cycle start time:  ${BigInt(cycleInfoResult[3])}`,
      `cycle duration:  ${BigInt(cycleInfoResult[4])}`,
      `maximum slots:  ${BigInt(cycleInfoResult[5])}`,
      ` has maximum slots:  ${BigInt(cycleInfoResult[6])}`,
      `cycle stake amount:  ${BigInt(cycleInfoResult[7])}`,
      `total stakes:  ${BigInt(cycleInfoResult[8])}`,
      `stake claimed:  ${BigInt(cycleInfoResult[9])}`,
      `cycle status:  ${BigInt(cycleInfoResult[10])}`,
      `stakes claimed before maturity:  ${BigInt(cycleInfoResult[11])}`,
      "cycle info"
    );

    let cycleMember = await cycleContract.getCycleMember("0");

    console.log(
      `cycle id: ${BigInt(cycleMember[0])}`,
      `grouop id:  ${BigInt(cycleMember[1])}`,
      `depositor address:  ${BigInt(cycleMember[2])}`,
      `ctotalLiquidityAsPenalty::  ${BigInt(cycleMember[3])}`,
      `number of cycle stakes:  ${BigInt(cycleMember[4])}`,
      `stakes claimed:  ${BigInt(cycleMember[5])}`,
      ` has withdrawn:  ${BigInt(cycleMember[6])}`,
      "cycle info"
    );
  });
});
