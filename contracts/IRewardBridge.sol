pragma solidity 0.6.6;


interface IRewardBridge  {

    function rewardUser(uint256 amount, address recipient) external;

    function updateTokenAddress(address newTokenAddress) external;

    function withdrawTokens(address tokenAddress) external;

    function withdrawTokens() external;
}
