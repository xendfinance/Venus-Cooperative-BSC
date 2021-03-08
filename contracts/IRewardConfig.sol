pragma solidity ^0.6.6;


interface IRewardConfig{

    function CalculateIndividualSavingsReward(uint256 totalCycleTimeInSeconds, uint256 amountDeposited) external view returns(uint256);

    function CalculateCooperativeSavingsReward(uint256 totalCycleTimeInSeconds, uint256 amountDeposited) external view returns(uint256);
    
    function CalculateEsusuReward(uint256 totalCycleTimeInSeconds, uint256 amountDeposited) external view returns(uint256);
}