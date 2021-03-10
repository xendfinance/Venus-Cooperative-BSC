pragma solidity 0.6.6;

interface IEsusuService {
    function GetGroupInformationByName(string calldata name) external view returns (uint groupId, string memory groupName, string memory groupSymbol, address groupCreatorAddress);
    function GetEsusuAdapterAddress() external view returns (address);
    
    
    function CreateGroup(string calldata name, string calldata symbol) external;
    function CreateEsusu(uint groupId, uint depositAmount, uint payoutIntervalSeconds,uint startTimeInSeconds,uint maxMembers) external;
    function JoinEsusu(uint esusuCycleId, address member) external;
    
    function GetMemberCycleInfo(address memberAddress, uint esusuCycleId) 
                                external view returns(uint CycleId, address MemberId, uint TotalAmountDepositedInCycle, 
                                uint TotalPayoutReceivedInCycle, uint memberPosition);
                                
     function GetEsusuCycle(uint esusuCycleId) external view returns(uint CycleId, uint DepositAmount, 
                                                            uint PayoutIntervalSeconds, uint CycleState, address Owner, 
                                                            uint TotalMembers, uint TotalAmountDeposited, uint TotalShares, 
                                                            uint TotalCycleDurationInSeconds, uint TotalCapitalWithdrawn, uint CycleStartTimeInSeconds,
                                                            uint TotalBeneficiaries);
    
    function StartEsusuCycle(uint esusuCycleId) external;
    
    function WithdrawROIFromEsusuCycle(uint esusuCycleId) external;
    
    function WithdrawCapitalFromEsusuCycle(uint esusuCycleId) external;
    
    function IsMemberEligibleToWithdrawROI(uint esusuCycleId, address member) external view returns(bool);
    
    function IsMemberEligibleToWithdrawCapital(uint esusuCycleId, address member) external view returns(bool);
    
    function GetCurrentEsusuCycleId() external view returns(uint);
    
    function GetTotalDeposits() external view returns(uint) ;
}