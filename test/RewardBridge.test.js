// const { assert } = require("console");

const assert = require('assert');


const Web3 = require("web3");

const web3 = new Web3("HTTP://127.0.0.1:8545");

const RewardBridgeContract = artifacts.require("RewardBridge");
const RewardTokenContract = artifacts.require("XendToken");




const unlockedAddress = "0x631fc1ea2270e98fbd9d92658ece0f5a269aa161";


var account1;
var account2;
var account3;

var account1Balance;
var account2Balance;
var account3Balance;

contract("RewardBridge", () => {
  let rewardBridgeInstance = null;
  let rewardTokenInstance = null;
 

  before(async () => {
    rewardBridgeInstance = await RewardBridgeContract.deployed();
    rewardTokenInstance = await RewardTokenContract.deployed();
    let numberOfTokensToTransfer = "1000000000000000000000"

    await rewardTokenInstance.transfer(rewardBridgeInstance.address,numberOfTokensToTransfer);
    console.log("11-> 1,000 Xend tokens transferred to reward bridge contract");
    let initialBalance = await rewardTokenInstance.balanceOf(rewardBridgeInstance.address);
  
   
  });

  it("Should deploy reward bridge contract", async () => {
    assert.notEqual(rewardBridgeInstance.address , "");

  });

  it("Reward bridge should have 1,000 Xt ", async () => {
    let tokenBalanceForBridge = BigInt(1000000000000000000000)
    let currentTokenBalanceForbridge = await rewardTokenInstance.balanceOf(rewardBridgeInstance.address);
    let balance = BigInt(currentTokenBalanceForbridge);
     assert.strictEqual(`${balance}`, `${tokenBalanceForBridge}`)
  });

 

  it("RewardUser should update the reward recipient balance", async()=>{
    let accounts = await web3.eth.getAccounts();
    let bridgeAddress = rewardBridgeInstance.address
    let initialBalance = await rewardTokenInstance.balanceOf(bridgeAddress);
    console.log({initialBalance})

    console.log({accounts});

    let rewardAmount = BigInt(500000000000000000000)
    let rewardRecipient = "0x1Eaa53161d6F1Ddc61629f521dD3Fb80e40Bd241";

    await rewardBridgeInstance.grantAccess(accounts[0]);

    await rewardBridgeInstance.rewardUser(rewardAmount.toString(),rewardRecipient);

    let currentTokenBalanceForbridge = await rewardTokenInstance.balanceOf(rewardBridgeInstance.address);
    let currentTokenbalanceForRecipient = await rewardTokenInstance.balanceOf(rewardBridgeInstance.address);

    assert.strictEqual(`${currentTokenBalanceForbridge}`, `${rewardAmount}`);
    assert.strictEqual(`${currentTokenbalanceForRecipient}`, `${rewardAmount}`);

  });

  it("Withdraw should empty the token balance of the Reward Bridge contract", async()=>{
    let accounts = await web3.eth.getAccounts();
    let bridgeAddress = rewardBridgeInstance.address
    let initialBalance = await rewardTokenInstance.balanceOf(bridgeAddress);
    console.log({initialBalance})

    await rewardBridgeInstance.withdrawTokens();

    let currentTokenBalanceForbridge = await rewardTokenInstance.balanceOf(rewardBridgeInstance.address);

    assert.strictEqual(`${currentTokenBalanceForbridge}`, `${0}`);

  });

  it("Update Token Address should update the reward token address", async()=>{
    let newRewardTokenAddress = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56";
    await rewardBridgeInstance.updateTokenAddress(newRewardTokenAddress)
    let updatedRewardTokenAddress = await rewardBridgeInstance.getTokenAddress();
    assert.strictEqual(newRewardTokenAddress,updatedRewardTokenAddress);
  });


  
});
