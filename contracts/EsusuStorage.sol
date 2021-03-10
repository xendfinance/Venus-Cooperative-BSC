pragma solidity 0.6.6;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";

contract EsusuStorage {

    using SafeMath for uint256;

    /*  Enum definitions */
    enum CurrencyEnum{
        Dai
    }

    enum CycleStateEnum{
        Idle,               // Cycle has just been created and members can join in this state
        Active,             // Cycle has started and members can take their ROI
        Expired,            // Cycle Duration has elapsed and members can withdraw their capital as well as ROI
        Inactive            // Total beneficiaries is equal to Total members, so all members have withdrawn their Capital and ROI
    }

    /*  Struct Definitions */
    struct EsusuCycle{
        uint256 CycleId;
        uint256 GroupId;                   //  Group this Esusu Cycle belongs to
        uint256 DepositAmount;
        uint256 TotalMembers;
        uint256 TotalBeneficiaries;        //  This is the total number of members that have withdrawn their ROI 
        uint256 PayoutIntervalSeconds;     //  Time each member receives overall ROI within one Esusu Cycle in seconds
        uint256 TotalCycleDuration;        //  The total time it will take for all users to be paid which is (number of members * payout interval)
        uint256 TotalAmountDeposited;      // Total  Dai Deposited
        uint256 TotalCapitalWithdrawn;     // Total Capital In Dai Withdrawn
        uint256 CycleStartTime;            //  Time, when the cycle starts has elapsed. Anyone can start cycle after this time has elapsed
        uint256 TotalShares;               //  Total yDai Shares 
        uint256 MaxMembers;                //  Maximum number of members that can join this esusu cycle
        uint256 TotalSharesAtStart;        //  Total shares at the start of the cycle, will use this to estimate the number of shares that belongs to each member
        address Owner;                  //  This is the creator of the cycle who is also the creator of the group
        CurrencyEnum Currency;          //  Currency supported in this Esusu Cycle 
        CycleStateEnum CycleState;      //  The current state of the Esusu Cycle

    }
    

    struct MemberCycle{
        uint256 CycleId;
        address MemberId;
        uint256 TotalAmountDepositedInCycle;
        uint256 TotalPayoutReceivedInCycle;
    }

        /*  Model definition starts */

    /* Model definition ends */

    //  Member variables
    address _owner;

    uint256 EsusuCycleId;
    
    mapping(uint256 => EsusuCycle) EsusuCycleMapping;

    mapping(address=>mapping(uint256 =>MemberCycle)) MemberAddressToMemberCycleMapping;

    mapping(uint256=>mapping(address => uint256)) CycleToMemberPositionMapping;   //  This tracks position of the  member in an Esusu Cycle

    mapping(uint256=>mapping(address => uint256)) CycleToBeneficiaryMapping;  // This tracks members that have received overall ROI and amount received within an Esusu Cycle

    mapping(uint256=>mapping(address=> uint)) CycleToMemberWithdrawnCapitalMapping;    // This tracks members that have withdrawn their capital and the amount withdrawn

    mapping(uint256=>uint256) GroupToCycleIndexMapping; //  This tracks the total number of cycles that belong to a group

    mapping(uint256=>mapping(uint256=>uint256)) GroupToCycleIndexToCycleIDMapping; //  This maps the Group to the cycle index and then the cycle ID

    mapping(address=>uint256) OwnerToCycleIndexMapping; //  This tracks the number of cycles by index created by an owner

    mapping(address=>mapping(uint256 => uint256)) OwnerToCycleIndexToCycleIDMapping; //  This maps the owner to the cycle index and then to the cycle ID

    mapping(address=>uint256) MemberToCycleIndexMapping; //  This tracks the number of cycles by index created by a member

    mapping(address=>mapping(uint256=>uint256)) MemberToCycleIndexToCycleIDMapping; //  This maps the member to the cycle index and then to the cycle ID

    mapping(address=>uint256) MemberToXendTokenRewardMapping;  //  This tracks the total amount of xend token rewards a member has received

    uint256 TotalDeposits; //  This holds all the dai amounts users have deposited in this contract


    address  _adapterContract;
    address _adapterDelegateContract;

    EsusuCycle [] EsusuCycles;  //  This holds the array of all EsusuCycles

    constructor () public {
        _owner = msg.sender;
    }

    function UpdateAdapterAndAdapterDelegateAddresses(address adapterContract, address adapterDelegateContract) onlyOwner external {
            _adapterContract = adapterContract;
            _adapterDelegateContract = adapterDelegateContract;
    }

    function GetEsusuCycleId() external view returns (uint){
        return EsusuCycleId;
    }

    function IncrementEsusuCycleId() external onlyOwnerAdapterAndAdapterDelegateContract {
        EsusuCycleId += 1;
    }
    
    function CreateEsusuCycleMapping(uint256 groupId, uint256 depositAmount, uint256 payoutIntervalSeconds,uint256 startTimeInSeconds, address owner, uint256 maxMembers) external onlyOwnerAdapterAndAdapterDelegateContract {
        
        EsusuCycleId += 1;
        EsusuCycle storage cycle = EsusuCycleMapping[EsusuCycleId];

        cycle.CycleId = EsusuCycleId;
        cycle.DepositAmount = depositAmount;
        cycle.PayoutIntervalSeconds = payoutIntervalSeconds;
        cycle.Currency = CurrencyEnum.Dai;
        cycle.CycleState = CycleStateEnum.Idle;
        cycle.Owner = owner;
        cycle.MaxMembers = maxMembers;


        //  Set the Cycle start time
        cycle.CycleStartTime = startTimeInSeconds;

         //  Assign groupId
        cycle.GroupId = groupId;
        GroupToCycleIndexMapping[groupId] = GroupToCycleIndexMapping[groupId].add(1); //  Increase the cycle index in the group by 1

        uint256 cycleIndex = GroupToCycleIndexMapping[groupId];
        mapping(uint256=>uint256) storage cylceIndexToCycleId = GroupToCycleIndexToCycleIDMapping[groupId];
        cylceIndexToCycleId[cycleIndex] = EsusuCycleId;

        // Increase the number of cycles created by the owner
        OwnerToCycleIndexMapping[owner] = OwnerToCycleIndexMapping[owner].add(1);

        uint256 ownerCreatedCycleIndex = OwnerToCycleIndexMapping[owner];
        mapping(uint256=>uint256) storage ownerCreatedCylceIndexToCycleId = OwnerToCycleIndexToCycleIDMapping[owner];
        ownerCreatedCylceIndexToCycleId[ownerCreatedCycleIndex] = EsusuCycleId;

        //  Push created cycle into array
        EsusuCycles.push(cycle);
    }

    function GetEsusuCycle(uint esusuCycleId) external view returns(uint CycleId, uint DepositAmount,
                                                            uint PayoutIntervalSeconds, uint CycleState,
                                                            uint TotalMembers, uint TotalAmountDeposited, uint TotalShares,
                                                            uint TotalCycleDurationInSeconds, uint TotalCapitalWithdrawn, uint CycleStartTimeInSeconds,
                                                            uint TotalBeneficiaries, uint MaxMembers){

        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");

        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];

        return (cycle.CycleId, cycle.DepositAmount,  cycle.PayoutIntervalSeconds,
                uint256(cycle.CycleState),
                cycle.TotalMembers, cycle.TotalAmountDeposited, cycle.TotalShares,
                cycle.TotalCycleDuration, cycle.TotalCapitalWithdrawn, cycle.CycleStartTime,
                cycle.TotalBeneficiaries, cycle.MaxMembers);        
    }



    function GetCycleIndexFromGroupId(uint groupId) external view returns(uint){

        return GroupToCycleIndexMapping[groupId];
    }

    function GetCycleIdFromCycleIndexAndGroupId(uint groupId, uint cycleIndex) external view returns(uint){

      mapping(uint=>uint) storage cylceIndexToCycleId = GroupToCycleIndexToCycleIDMapping[groupId];

      return cylceIndexToCycleId[cycleIndex];
    }

    function GetCycleIndexFromCycleCreator(address cycleCreator) external view returns(uint){

        return OwnerToCycleIndexMapping[cycleCreator];
    }

    function GetCycleIdFromCycleIndexAndCycleCreator(uint cycleIndex, address cycleCreator) external view returns(uint){

      mapping(uint=>uint) storage ownerCreatedCylceIndexToCycleId = OwnerToCycleIndexToCycleIDMapping[cycleCreator];

      return ownerCreatedCylceIndexToCycleId[cycleIndex];
    }

    function GetCycleIndexFromCycleMember(address member) external view returns(uint){

        return MemberToCycleIndexMapping[member];
    }

    function GetCycleIdFromCycleIndexAndCycleMember(uint cycleIndex, address member) external view returns(uint){

      mapping(uint=>uint) storage memberCreatedCylceIndexToCycleId = MemberToCycleIndexToCycleIDMapping[member];

      return memberCreatedCylceIndexToCycleId[cycleIndex];
    }



    function GetEsusuCycleBasicInformation(uint esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint CycleId, uint DepositAmount, uint CycleState,uint TotalMembers,uint MaxMembers, uint PayoutIntervalSeconds, uint GroupId){

        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];

        return (cycle.CycleId, cycle.DepositAmount,
                uint256(cycle.CycleState),
                cycle.TotalMembers, cycle.MaxMembers, cycle.PayoutIntervalSeconds, cycle.GroupId);
        
    } 
    
    
    function GetEsusuCycleTotalShares(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 TotalShares){
                        
        return (EsusuCycleMapping[esusuCycleId].TotalShares);
    }                                                        

    function GetEsusuCycleStartTime(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 EsusuCycleStartTime){
                         
        return (EsusuCycleMapping[esusuCycleId].CycleStartTime);      
    }
    
    
    function GetEsusuCyclePayoutInterval(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 EsusuCyclePayoutInterval){
                         
        return (EsusuCycleMapping[esusuCycleId].PayoutIntervalSeconds);      
    }
    
    function GetEsusuCycleTotalAmountDeposited(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 EsusuCycleTotalAmountDeposited){
                        
        return (EsusuCycleMapping[esusuCycleId].TotalAmountDeposited);      
    }
    
    function GetCycleOwner(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(address EsusuCycleOwner){
                        
        return (EsusuCycleMapping[esusuCycleId].Owner);
        
    }
    
    function GetEsusuCycleDuration(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 EsusuCycleDuration){
        
        return (EsusuCycleMapping[esusuCycleId].TotalCycleDuration);    
    }
    
    function GetEsusuCycleTotalCapitalWithdrawn(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 EsusuCycleTotalCapitalWithdrawn){
                        
        return (EsusuCycleMapping[esusuCycleId].TotalCapitalWithdrawn);       
    }
    function GetEsusuCycleTotalBeneficiaries(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 EsusuCycleTotalBeneficiaries){
                        
        return (EsusuCycleMapping[esusuCycleId].TotalBeneficiaries);       
    }
    function GetMemberWithdrawnCapitalInEsusuCycle(uint256 esusuCycleId,address memberAddress) external view returns (uint) {
                        
        return CycleToMemberWithdrawnCapitalMapping[esusuCycleId][memberAddress];
    }
    
    function GetMemberCycleToBeneficiaryMapping(uint256 esusuCycleId,address memberAddress) external view returns(uint){
        
        return CycleToBeneficiaryMapping[esusuCycleId][memberAddress];
    }
    
    function GetTotalMembersInCycle(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 TotalMembers){
                         
        return (EsusuCycleMapping[esusuCycleId].TotalMembers);      
    }

    function IsMemberInCycle(address memberAddress,uint256 esusuCycleId ) external view returns(bool){
        return MemberAddressToMemberCycleMapping[memberAddress][esusuCycleId].CycleId > 0;
    }
    
    function IncreaseTotalAmountDepositedInCycle(uint256 esusuCycleId, uint256 amount) isCycleIdValid(esusuCycleId) external onlyOwnerAdapterAndAdapterDelegateContract returns (uint){
    
        EsusuCycle storage cycle = EsusuCycleMapping[EsusuCycleId];

        uint256 amountDeposited = cycle.TotalAmountDeposited.add(amount);

        cycle.TotalAmountDeposited =  amountDeposited;

        //  Update cycle in the array
        EsusuCycle storage esusuCycle = EsusuCycles[EsusuCycleId - 1];
        esusuCycle.TotalAmountDeposited =  amountDeposited;

        
        return amountDeposited;
    }
    
    function CreateMemberAddressToMemberCycleMapping(address member,uint256 esusuCycleId ) isCycleIdValid(esusuCycleId) external onlyOwnerAdapterAndAdapterDelegateContract{
        
        //  Increment the total deposited amount for the member cycle struct
        mapping(uint=>MemberCycle) storage memberCycleMapping =  MemberAddressToMemberCycleMapping[member];
        
        memberCycleMapping[esusuCycleId].CycleId = esusuCycleId;
        memberCycleMapping[esusuCycleId].MemberId = member;
        memberCycleMapping[esusuCycleId].TotalAmountDepositedInCycle = memberCycleMapping[esusuCycleId].TotalAmountDepositedInCycle.add( EsusuCycleMapping[esusuCycleId].DepositAmount);        
    }
    

    
    function GetEsusuCycleTotalSharesAtStart(uint esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint TotalSharesAtStart){


        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];

        return (cycle.TotalSharesAtStart);
    }


    function IncreaseTotalMembersInCycle(uint esusuCycleId) isCycleIdValid(esusuCycleId) external onlyOwnerAdapterAndAdapterDelegateContract{
        //  Increase TotalMembers count by 1

        EsusuCycleMapping[esusuCycleId].TotalMembers +=1;
       
        //  Update cycle in the array
        EsusuCycle storage esusuCycle = EsusuCycles[EsusuCycleId - 1];
        esusuCycle.TotalMembers = EsusuCycleMapping[esusuCycleId].TotalMembers;
    }    
    function CreateMemberPositionMapping(uint256 esusuCycleId, address member) isCycleIdValid(esusuCycleId) onlyOwnerAdapterAndAdapterDelegateContract external{
        
        mapping(address=>uint) storage memberPositionMapping =  CycleToMemberPositionMapping[esusuCycleId];

        //  Assign Position to Member In this Cycle
        memberPositionMapping[member] = EsusuCycleMapping[esusuCycleId].TotalMembers;
    }    
    function IncreaseTotalDeposits(uint256 esusuCycleBalance) external onlyOwnerAdapterAndAdapterDelegateContract {
        
        TotalDeposits = TotalDeposits.add(esusuCycleBalance);

    }
    
    function UpdateEsusuCycleDuringStart(uint256 esusuCycleId,uint256 cycleStateEnum, uint256 toalCycleDuration, uint256 totalShares,uint256 currentTime) external onlyOwnerAdapterAndAdapterDelegateContract{
       
        EsusuCycle storage cycle = EsusuCycleMapping[esusuCycleId];

        cycle.TotalCycleDuration = toalCycleDuration;
        cycle.CycleState = CycleStateEnum(cycleStateEnum); 
        cycle.TotalShares = totalShares;
        cycle.CycleStartTime = currentTime;
        cycle.TotalSharesAtStart = totalShares;

        //  Update cycle in the array
        EsusuCycle storage esusuCycle = EsusuCycles[esusuCycleId - 1];
        esusuCycle.TotalCycleDuration = toalCycleDuration;
        esusuCycle.CycleState = CycleStateEnum(cycleStateEnum);
        esusuCycle.TotalShares = totalShares;
        esusuCycle.CycleStartTime = currentTime;
        esusuCycle.TotalSharesAtStart = totalShares;

    }
    
    function UpdateEsusuCycleState(uint256 esusuCycleId,uint256 cycleStateEnum) external onlyOwnerAdapterAndAdapterDelegateContract{
       
        EsusuCycleMapping[esusuCycleId].CycleState = CycleStateEnum(cycleStateEnum); 
        
        //  Update cycle in the array
        EsusuCycle storage esusuCycle = EsusuCycles[esusuCycleId - 1];
        esusuCycle.TotalShares = EsusuCycleMapping[esusuCycleId].TotalShares;
    }
    function GetMemberCycleInfo(address memberAddress, uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 CycleId, address MemberId, uint256 TotalAmountDepositedInCycle, uint256 TotalPayoutReceivedInCycle, uint256 memberPosition){
                
        mapping(uint=>MemberCycle) storage memberCycleMapping =  MemberAddressToMemberCycleMapping[memberAddress];

        mapping(address=>uint) storage memberPositionMapping =  CycleToMemberPositionMapping[esusuCycleId];        
        //  Get Number(Position) of Member In this Cycle
        return  (memberCycleMapping[esusuCycleId].CycleId,memberCycleMapping[esusuCycleId].MemberId,
        memberCycleMapping[esusuCycleId].TotalAmountDepositedInCycle,
        memberCycleMapping[esusuCycleId].TotalPayoutReceivedInCycle,memberPositionMapping[memberAddress]);
    }
    
    function CreateMemberCapitalMapping(uint256 esusuCycleId, address member) external onlyOwnerAdapterAndAdapterDelegateContract {
         
        mapping(address=>uint) storage memberCapitalMapping =  CycleToMemberWithdrawnCapitalMapping[esusuCycleId];
        memberCapitalMapping[member] = EsusuCycleMapping[esusuCycleId].DepositAmount;
    }
    
    function UpdateEsusuCycleDuringCapitalWithdrawal(uint256 esusuCycleId, uint256 cycleTotalShares, uint256 totalCapitalWithdrawnInCycle) external onlyOwnerAdapterAndAdapterDelegateContract{
        
        EsusuCycleMapping[esusuCycleId].TotalCapitalWithdrawn = totalCapitalWithdrawnInCycle; 
        EsusuCycleMapping[esusuCycleId].TotalShares = cycleTotalShares;

        //  Update cycle in the array
        EsusuCycle storage esusuCycle = EsusuCycles[esusuCycleId - 1];
        esusuCycle.TotalCapitalWithdrawn = totalCapitalWithdrawnInCycle;
        esusuCycle.TotalShares = cycleTotalShares;
    }
    
    function UpdateEsusuCycleDuringROIWithdrawal(uint256 esusuCycleId, uint256 totalShares, uint256 totalBeneficiaries) external onlyOwnerAdapterAndAdapterDelegateContract{
        EsusuCycleMapping[esusuCycleId].TotalBeneficiaries = totalBeneficiaries; 
        EsusuCycleMapping[esusuCycleId].TotalShares = totalShares;  

        //  Update cycle in the array
        EsusuCycle storage esusuCycle = EsusuCycles[esusuCycleId - 1];
        esusuCycle.TotalBeneficiaries = totalBeneficiaries;
        esusuCycle.TotalShares = totalShares;      
    }
    
    function CreateEsusuCycleToBeneficiaryMapping(uint256 esusuCycleId, address memberAddress, uint256 memberROINet) external onlyOwnerAdapterAndAdapterDelegateContract{
        
        mapping(address=>uint) storage beneficiaryMapping =  CycleToBeneficiaryMapping[esusuCycleId];

        beneficiaryMapping[memberAddress] = memberROINet;
    }

    function CalculateMemberWithdrawalTime(uint256 cycleId, address member) external view returns(uint256 withdrawalTime){

        mapping(address=>uint) storage memberPositionMapping = CycleToMemberPositionMapping[cycleId];

        uint256 memberPosition = memberPositionMapping[member];

        withdrawalTime = (EsusuCycleMapping[cycleId].CycleStartTime.add(memberPosition.mul(EsusuCycleMapping[cycleId].PayoutIntervalSeconds)));
        return withdrawalTime;
    }

    function CreateMemberToCycleIndexToCycleIDMapping(address member, uint256 esusuCycleId) external onlyOwnerAdapterAndAdapterDelegateContract {
      // Increase the number of cycles joined by the member
      MemberToCycleIndexMapping[member] = MemberToCycleIndexMapping[member].add(1);

      uint256 memberCreatedCycleIndex = MemberToCycleIndexMapping[member];
      mapping(uint256=>uint256) storage memberCreatedCylceIndexToCycleId = MemberToCycleIndexToCycleIDMapping[member];
      memberCreatedCylceIndexToCycleId[memberCreatedCycleIndex] = esusuCycleId;
    }

    function GetTotalDeposits() external view returns (uint256){
        return TotalDeposits;
    }

    function GetEsusuCycleState(uint256 esusuCycleId) external view returns (uint256){
        
        return uint256(EsusuCycleMapping[esusuCycleId].CycleState);

    }

    function UpdateMemberToXendTokeRewardMapping(address member, uint256 rewardAmount) external onlyOwnerAdapterAndAdapterDelegateContract {
        MemberToXendTokenRewardMapping[member] = MemberToXendTokenRewardMapping[member].add(rewardAmount);
    }

    function GetMemberXendTokenReward(address member) external view returns(uint256) {
        return MemberToXendTokenRewardMapping[member];
    }

    //  Get the EsusuCycle Array
    function GetEsusuCycles() external view returns (EsusuCycle [] memory){
        return EsusuCycles;
    }
    
    modifier onlyOwner() {
        require(msg.sender == _owner, "Unauthorized access to contract");
        _;
    }

    modifier onlyOwnerAdapterAndAdapterDelegateContract() {
        require(
            msg.sender == _owner || msg.sender == _adapterDelegateContract || msg.sender == _adapterContract,
            "Unauthorized access to contract"
        );
        _;
    }

    modifier isCycleIdValid(uint256 esusuCycleId) {

        require(esusuCycleId != 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        _;
    }
    



        /**
        NOTE: before now, we update the cycle during start but because of ForTube precision issue
        we now update the cycle once a member joins the cycle. We also invest member's funds immediately they join so 
        as to increase the exchangeRateStored on ForTube. 
        This function will not be important on Yearn Finance on the ethereum blockchain
     */
    function UpdateEsusuCycleSharesDuringJoin(uint esusuCycleId, uint memberShares) external onlyOwnerAdapterAndAdapterDelegateContract{
          
        EsusuCycleMapping[esusuCycleId].TotalShares = EsusuCycleMapping[esusuCycleId].TotalShares.add(memberShares);
        
        //  Update cycle in the array
        EsusuCycle storage esusuCycle = EsusuCycles[esusuCycleId - 1];
        esusuCycle.TotalShares = EsusuCycleMapping[esusuCycleId].TotalShares;  
    }
}
