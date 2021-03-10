pragma solidity 0.6.6;

import "./Ownable.sol";
import "./IEsusuService.sol";
import "./IGroups.sol";
import "./SafeMath.sol";



/*
    @Brief: This contract should calculate the Xend Token reward for users. This contract implements the reward system as described in Litepaper but this is
    much more detailed

    1. We must get the Current Threshold level which is determined by the total amount deposited on the different smart contracts
    2. They perform one or more of the following operations (Individual savings, cooperative savings, esusu)
    3. The users must meet the timelock conditions per operation to receive reward for that condition
    4. Create timelock to Category to CategoryRewardFactor Mapping
    5. Once a new threshold level is reached, we will add it to the threshold level mapping with maximum Xend Tokens to be distributed in that level
    6. We should be able to stop reward distribution by the owner
    7. This contract can be replaced at anytime and updated in calling contracts

    TODO: Add tracker to know at what treshold a user invested so as to ensure we paid the exact amount

*/
contract RewardConfig is Ownable {

    using SafeMath for uint256;


    constructor(address esusuServiceContract, address groupServiceContract) public{

        iEsusuService = IEsusuService(esusuServiceContract);

        //  NOTE: The groups contracts holds overall deposits for all savings , i.e Individual savings and groups savings
        savingsStorage = IGroups(groupServiceContract);
    }

    IEsusuService immutable iEsusuService;
    IGroups immutable savingsStorage;
    address immutable daiTokenAddress = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;


    uint CurrentThresholdLevel;                 //

        
    mapping(uint256 => uint)   DurationToRewardFactorMapping;
    
    uint256 InitialThresholdValueInUSD;
    uint256 XendTokenRewardAtInitialThreshold;
    uint256 DepreciationFactor;
    uint256 SavingsCategoryRewardFactor;   //  Cir -> 0.7 (but we have to make it 7 to handle decimal)
    uint256 GroupCategoryRewardFactor;     //  Cgr -> 1.0 (but we have to make it 10 to handle decimal)
    uint256 EsusuCategoryRewardFactor;     //  Cer -> 1.5 (but we have to make it 10 to handle decimal)
    
    
    //  The member variables below determine the reward factor based on time. 
    //  NOTE: Ensure that the PercentageRewardFactorPerTimeLevel at 100% corresponds with MaximumTimeLevel. It means MaximumTimeLevel/PercentageRewardFactorPerTimeLevel = 1
    
    uint256 PercentageRewardFactorPerTimeLevel;    //  This determines the percentage of the reward factor paid for each time level eg 4 means 25%, 5 means 20%
    uint256 MinimumNumberOfSeconds = 2592000;      //  This determines whether we are checking time level by days, weeks, months or years. It is 30 days(1 month) in seconds by default
    uint256 MaximumTimeLevel;                      //  This determines how many levels can be derived based on the MinimumNumberOfSeconds that has been set
    bool RewardActive;



    /*
        -   Sets the inital threshold value in USD (value in 1e18)
        -   Sets XendToken reward at the initial threshold (value in 1e18)
        -   Sets DepreciationFactor

    */
    function SetRewardParams(uint256 thresholdValue, uint256 xendTokenReward, uint256 depreciationFactor, 
                                uint256 savingsCategoryRewardFactor, uint256 groupCategoryRewardFactor, 
                                uint256 esusuCategoryRewardFactor, uint256 percentageRewardFactorPerTimeLevel,
                                uint256 minimumNumberOfSeconds, uint256 maximumTimeLevel) onlyOwner external{
        require(PercentageRewardFactorPerTimeLevel == MaximumTimeLevel, "Values must be the same to achieve unity at maximum level");
        InitialThresholdValueInUSD = thresholdValue;
        XendTokenRewardAtInitialThreshold = xendTokenReward;
        DepreciationFactor = depreciationFactor;
        SavingsCategoryRewardFactor = savingsCategoryRewardFactor;
        GroupCategoryRewardFactor = groupCategoryRewardFactor;
        EsusuCategoryRewardFactor = esusuCategoryRewardFactor;
        PercentageRewardFactorPerTimeLevel = percentageRewardFactorPerTimeLevel;
        MinimumNumberOfSeconds = minimumNumberOfSeconds;
        MaximumTimeLevel = maximumTimeLevel;

    }

    /*
        This function calculates XTr for individual savings based on the total cycle time and amountDeposited
    */
    function CalculateIndividualSavingsReward(uint256 totalCycleTimeInSeconds, uint256 amountDeposited) external view returns(uint256 individualSavingsReward){
        
        //  If we are not currently rewarding users, return 0
        if(!RewardActive){
            return 0;
        }
        
        uint256 Cir = CalculateCategoryFactor(totalCycleTimeInSeconds,SavingsCategoryRewardFactor);
        uint256 XTf = CalculateRewardFactorForCurrentThresholdLevel();
        uint256 XTr = XTf.mul(Cir);    // NOTE: this value is in 1e18 
        
        // return XTr * amountdeposited and divided by 1e18 since the amount is already in the wei unit 

        individualSavingsReward = XTr.mul(amountDeposited).div(1e36);
        
        return individualSavingsReward;
    }

    /*
        This function calculates XTr for group or cooperative or Group savings based on the total cycle time and amountDeposited
    */
    function CalculateCooperativeSavingsReward(uint256 totalCycleTimeInSeconds, uint256 amountDeposited) external view returns(uint256 groupSavingsReward){
        
        //  If we are not currently rewarding users, return 0
        if(!RewardActive){
            return 0;
        }
        
        uint256 Cgr = CalculateCategoryFactor(totalCycleTimeInSeconds,GroupCategoryRewardFactor);
        uint256 XTf = CalculateRewardFactorForCurrentThresholdLevel();
        uint256 XTr = XTf.mul(Cgr);    // NOTE: this value is in 1e18 which is correct
        
        // return XTr * amountdeposited and divided by 1e18 since the amount is already in the wei unit 

        groupSavingsReward = XTr.mul(amountDeposited).div(1e36);
        return groupSavingsReward;
    }

    /*
        This function calculates XTr for Esusu based on the total cycle time and amountDeposited
    */
    function CalculateEsusuReward(uint256 totalCycleTimeInSeconds, uint256 amountDeposited) external view returns(uint256 groupSavingsReward){
        
        //  If we are not currently rewarding users, return 0
        if(!RewardActive){
            return 0;
        }
        
        uint256 Cer = CalculateCategoryFactor(totalCycleTimeInSeconds,EsusuCategoryRewardFactor);
        uint256 XTf = CalculateRewardFactorForCurrentThresholdLevel();
        uint256 XTr = XTf.mul(Cer);    // NOTE: this value is in 1e18 which is correct
        
        // return XTr * amountdeposited and divided by 1e18 since the amount is already in the wei unit 

        groupSavingsReward = XTr.mul(amountDeposited).div(1e36);
        return groupSavingsReward;
    }

    /*
        -   Get the RewardTimeLevel based on the totalCycleTimeInSeconds
        -   Get the PercentageRewardFactor based on the RewardTimeLevel : NOTE value is in 1e18
        -   Reward value is multiplied by 10 because it is usually a decimal based on the category 
    */
    
    function CalculateCategoryFactor(uint256 totalCycleTimeInSeconds, uint256 reward) public view returns(uint256 result){
        
        uint256 timeLevel = GetRewardTimeLevel(totalCycleTimeInSeconds);
        
        uint256 percentageRewardFactor = CalculatePercentageRewardFactor(timeLevel);
        
        result = percentageRewardFactor.mul(reward).div(10);
        
        return result;
    }

    /*
        1. Get the CurrentThresholdLevel
        2. Get reward factor for current threshold level (XTf) => Xend Token Threshold Per Level / Deposit Threshold for that level in USD

    */
    function CalculateRewardFactorForCurrentThresholdLevel() public view returns(uint256 XTf){
        
        uint256 level = GetCurrentThresholdLevel();
        uint256 currentDepositThreshold = level.mul(InitialThresholdValueInUSD);
        uint256 currentXendTokenRewardThreshold = GetCurrentXendTokenRewardThresholdAtCurrentLevel();
        XTf = currentXendTokenRewardThreshold.mul(1e18).div(currentDepositThreshold);
        
        return XTf;
    }



    /*
        - This function gets the total deposits from all XendFinance smart contracts
        - tokenAddress is required to get total deposits for the savings storage contract . Esusu service works only with DAI
    */
    function GetTotalDeposits() public view returns(uint256 result){
        
        uint256 esusuDesposit = iEsusuService.GetTotalDeposits();
        
        uint256 savingsDeposit = savingsStorage.getTokenDeposit(daiTokenAddress);
        
        result = esusuDesposit.add(savingsDeposit);
        
        return result;
    }
    
    function GetCurrentThresholdLevel() public view returns(uint256 level){
        
        uint256 totalDeposits = GetTotalDeposits();
        uint256 initialThresholdValue = InitialThresholdValueInUSD;
        
        level = totalDeposits.div(initialThresholdValue);
         
         if (level == 0){
             return 1;
         }

         return level;
    }
    
    function GetCurrentXendTokenRewardThresholdAtCurrentLevel() public view returns(uint256 result){
        
        uint256 level = GetCurrentThresholdLevel();
        result = XendTokenRewardAtInitialThreshold.div(DepreciationFactor ** level.sub(1));
        
        return result;
    }


    /*
        - Reward time levels determine the amount of reward you will receive based on the total time of the savings cycle
        - Minimum reward time is 30 days which is 2592000 seconds
        - If the Timelevel is 0, user does not get any Xend Token reward
        - User gets maximum Xend Token reward from Timelevel 4 since the PercentageRewardFactor will return 100%
    */
    
    function GetRewardTimeLevel(uint256 totalCycleTimeInSeconds) public view returns(uint256 level){
        
        
        level = totalCycleTimeInSeconds.div(MinimumNumberOfSeconds);
        
        if(level >= MaximumTimeLevel){
            level = MaximumTimeLevel;
        }
        return level;
    }

    /*
        -   This function calculates the percentage of the reward factor per time level.
        -   PercentageRewardFactor = TimeLevel / PercentageRewardFactorPerTimeLevel
        -   Value is returned in 1e18 to handle decimals
    */
    function CalculatePercentageRewardFactor(uint256 rewardTimeLevel) public view returns(uint256 result){
        
        result = rewardTimeLevel.mul(1e18).div(PercentageRewardFactorPerTimeLevel);
        
        return result;
    }

    function SetRewardActive(bool isActive) onlyOwner external {
        RewardActive = isActive;
    }

    function GetRewardActive() external view returns(bool rewardActiveStatus){
        return RewardActive;
    }
}
