pragma solidity 0.6.6;

interface IEsusuService {
    function GetGroupInformationByName(string calldata name) external view returns (uint256 groupId, string memory groupName, string memory groupSymbol, address groupCreatorAddress);
    function GetEsusuAdapterAddress() external view returns (address);
    
    
    function CreateGroup(string calldata name, string calldata symbol) external;
    function CreateEsusu(uint256 groupId, uint256 depositAmount, uint256 payoutIntervalSeconds,uint256 startTimeInSeconds,uint256 maxMembers) external;
    function JoinEsusu(uint256 esusuCycleId, address member) external;
    
    function GetMemberCycleInfo(address memberAddress, uint256 esusuCycleId) 
                                external view returns(uint256 CycleId, address MemberId, uint256 TotalAmountDepositedInCycle, 
                                uint256 TotalPayoutReceivedInCycle, uint256 memberPosition);
                                
     function GetEsusuCycle(uint256 esusuCycleId) external view returns(uint256 CycleId, uint256 DepositAmount, 
                                                            uint256 PayoutIntervalSeconds, uint256 CycleState, address Owner, 
                                                            uint256 TotalMembers, uint256 TotalAmountDeposited, uint256 TotalShares, 
                                                            uint256 TotalCycleDurationInSeconds, uint256 TotalCapitalWithdrawn, uint256 CycleStartTimeInSeconds,
                                                            uint256 TotalBeneficiaries);
    
    function StartEsusuCycle(uint256 esusuCycleId) external;
    
    function WithdrawROIFromEsusuCycle(uint256 esusuCycleId) external;
    
    function WithdrawCapitalFromEsusuCycle(uint256 esusuCycleId) external;
    
    function IsMemberEligibleToWithdrawROI(uint256 esusuCycleId, address member) external view returns(bool);
    
    function IsMemberEligibleToWithdrawCapital(uint256 esusuCycleId, address member) external view returns(bool);
    
    function GetCurrentEsusuCycleId() external view returns(uint256);
    
    function GetTotalDeposits() external view returns(uint256) ;
}