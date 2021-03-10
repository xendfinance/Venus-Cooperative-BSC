pragma solidity >=0.6.6;

interface IEsusuStorage {
    /* Getters */
    function GetEsusuCycleId() external view returns(uint);

    function GetEsusuCycle(uint esusuCycleId) external view returns(uint CycleId, uint DepositAmount,
                                                            uint PayoutIntervalSeconds, uint CycleState,
                                                            uint TotalMembers, uint TotalAmountDeposited, uint TotalShares,
                                                            uint TotalCycleDurationInSeconds, uint TotalCapitalWithdrawn, uint CycleStartTimeInSeconds,
                                                            uint TotalBeneficiaries, uint MaxMembers);
    function GetEsusuCycleBasicInformation(uint esusuCycleId) external view returns(uint CycleId, uint DepositAmount, uint CycleState,uint TotalMembers,uint MaxMembers);
    function GetEsusuCycleTotalShares(uint esusuCycleId) external view returns(uint TotalShares);
    function GetEsusuCycleStartTime(uint esusuCycleId)external view returns(uint EsusuCycleStartTime);
    function GetEsusuCyclePayoutInterval(uint esusuCycleId)external view returns(uint EsusuCyclePayoutInterval);
    function GetEsusuCycleTotalAmountDeposited(uint esusuCycleId)external view returns(uint EsusuCycleTotalAmountDeposited);
    function GetEsusuCycleDuration(uint esusuCycleId)external view returns(uint EsusuCycleDuration);
    function GetEsusuCycleTotalCapitalWithdrawn(uint esusuCycleId)external view returns(uint EsusuCycleTotalCapitalWithdrawn);
    function GetEsusuCycleTotalBeneficiaries(uint esusuCycleId)external view returns(uint EsusuCycleTotalBeneficiaries);

    function GetCycleOwner(uint esusuCycleId)external view returns(address EsusuCycleOwner);
    function GetMemberCycleInfo(address memberAddress, uint esusuCycleId) external view returns(uint CycleId, address MemberId, uint TotalAmountDepositedInCycle, uint TotalPayoutReceivedInCycle, uint memberPosition);
    function GetMemberWithdrawnCapitalInEsusuCycle(uint esusuCycleId,address memberAddress) external view returns (uint);
    function GetMemberCycleToBeneficiaryMapping(uint esusuCycleId,address memberAddress) external view returns(uint);
    function IsMemberInCycle(address memberAddress,uint esusuCycleId ) external view returns(bool);
    function CalculateMemberWithdrawalTime(uint cycleId, address member) external view returns(uint);
    function GetTotalDeposits() external view returns (uint);
    function GetEsusuCycleState(uint esusuCycleId) external view returns (uint);
    function GetTotalMembersInCycle(uint esusuCycleId)external view returns(uint TotalMembers); 
    function GetEsusuCycleTotalSharesAtStart(uint esusuCycleId) external view returns(uint TotalSharesAtStart);
    function GetCycleIndexFromGroupId(uint groupId) external view returns(uint);
    function GetCycleIdFromCycleIndexAndGroupId(uint groupId, uint cycleIndex) external view returns(uint);
    function GetCycleIndexFromCycleCreator(address cycleCreator) external view returns(uint);
    function GetCycleIdFromCycleIndexAndCycleCreator(uint cycleIndex, address cycleCreator) external view returns(uint);
    function GetCycleIndexFromCycleMember(address member) external view returns(uint);
    function GetCycleIdFromCycleIndexAndCycleMember(uint cycleIndex, address member) external view returns(uint);
    function GetMemberXendTokenReward(address member) external returns(uint);


    /* Setters - only owner or service contract can call */

    function CreateEsusuCycleMapping(uint groupId, uint depositAmount, uint payoutIntervalSeconds,uint startTimeInSeconds, address owner, uint maxMembers) external;
    function IncreaseTotalAmountDepositedInCycle(uint esusuCycleId, uint amount) external returns(uint);
    function CreateMemberAddressToMemberCycleMapping(address member,uint esusuCycleId) external;
    function IncreaseTotalMembersInCycle(uint esusuCycleId) external;
    function CreateMemberPositionMapping(uint esusuCycleId, address member) external;
    function IncreaseTotalDeposits(uint esusuCycleBalance) external;
    function UpdateEsusuCycleDuringStart(uint esusuCycleId,uint cycleStateEnum, uint toalCycleDuration, uint totalShares,uint currentTime) external;
    function UpdateEsusuCycleState(uint esusuCycleId,uint cycleStateEnum) external;
    function CreateMemberCapitalMapping(uint esusuCycleId, address member) external;
    function UpdateEsusuCycleDuringCapitalWithdrawal(uint esusuCycleId, uint cycleTotalShares, uint totalCapitalWithdrawnInCycle) external;
    function UpdateEsusuCycleDuringROIWithdrawal(uint esusuCycleId, uint totalShares, uint totalBeneficiaries) external;
    function CreateEsusuCycleToBeneficiaryMapping(uint esusuCycleId, address memberAddress, uint memberROINet) external;
    function CreateMemberToCycleIndexToCycleIDMapping(address member, uint esusuCycleId) external;
    function UpdateEsusuCycleSharesDuringJoin(uint esusuCycleId, uint memberShares) external;
    function UpdateMemberToXendTokeRewardMapping(address member, uint rewardAmount) external;
}
