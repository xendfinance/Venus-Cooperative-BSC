const { assert, group } = require("console");

const Web3 = require("web3");

const web3 = new Web3("HTTP://127.0.0.1:8545");

const GroupsContract = artifacts.require("Groups");

const CycleContract = artifacts.require("Cycles")

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

contract("XendFinanceIndividual_Yearn_V1", () => {
  let contractInstance = null;
  let savingsConfigContract = null;
  let xendTokenContract = null;
  let venusLendingService = null;
  let rewardConfigContract = null;
  let venusAdapter = null;
  let xendGroupsContract = null;
  let cycleContract = null;
  let groupsContract = null;

  beforeEach(async () => {
    savingsConfigContract = await SavingsConfigContract.deployed();
    xendTokenContract = await XendTokenContract.deployed();
    venusLendingService = await VenusLendingService.deployed();
    clientRecordContract = await ClientRecordContract.deployed();
    rewardConfigContract = await RewardConfigContract.deployed();
    venusAdapter = await VenusAdapter.deployed();
    cycleContract = await CycleContract.deployed();
    groupsContract = await GroupsContract.deployed();
    xendGroupsContract = await XendFinanceGroup.deployed();
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

    console.log(xendGroupsContract.address, "contract address")
    assert(xendGroupsContract.address !== "");
  });

  it("Should create a group with account 1", async () => {
    await xendGroupsContract.createGroup("Njoku Master", "NJ");

    let groupInfo = await xendGroupsContract.getGroupById("1");

    console.log(groupInfo, 'group information')
  })

})
  
