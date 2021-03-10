pragma solidity 0.6.6;

import "./EsusuAdapter.sol";
import "./EsusuAdapterWithdrawalDelegate.sol";


contract EsusuService{

    address _owner;
    EsusuAdapter _esusuAdapter;
    EsusuAdapterWithdrawalDelegate _esusuAdapterWithdrawalDelegate;
    
    constructor() public {
        _owner = msg.sender;
    }

    function TransferOwnership(address account) onlyOwner() external{
        _owner = account;
    }

    function UpdateAdapter(address adapterAddress) onlyOwner() external{
        _esusuAdapter = EsusuAdapter(adapterAddress);
    }

    function UpdateAdapterWithdrawalDelegate(address delegateAddress) onlyOwner() external{
        _esusuAdapterWithdrawalDelegate = EsusuAdapterWithdrawalDelegate(delegateAddress);
    }
    
    function GetGroupInformationByName(string calldata name) external view returns (uint256 groupId, string memory groupName, string memory groupSymbol, address groupCreatorAddress){
        

        return _esusuAdapter.GetGroupInformationByName(name);
    }

    function GetEsusuAdapterAddress() external view returns (address){
        return address(_esusuAdapter);
    }


    function CreateGroup(string calldata name, string calldata symbol) external {

           _esusuAdapter.CreateGroup(name,symbol,msg.sender);

    }
    
    function CreateEsusu(uint256 groupId, uint256 depositAmount, uint256 payoutIntervalSeconds,uint256 startTimeInSeconds,uint256 maxMembers) external {
         
        require(depositAmount > 0, "Deposit Amount Can't Be Zero");       
        _esusuAdapter.CreateEsusu(groupId,depositAmount,payoutIntervalSeconds,startTimeInSeconds,msg.sender,maxMembers);
    }

    /*
        NOTE: member must approve _esusuAdapter to transfer deposit amount on his/her behalf
    */
    function JoinEsusu(uint256 esusuCycleId) external {
        _esusuAdapter.JoinEsusu(esusuCycleId,msg.sender);
    }


    /*
        This function returns information about a member in an esusu Cycle
    */
    function GetMemberCycleInfo(address memberAddress, uint256 esusuCycleId) 
                                external view returns(uint256 CycleId, address MemberId, uint256 TotalAmountDepositedInCycle, 
                                uint256 TotalPayoutReceivedInCycle, uint256 memberPosition){
        
        return _esusuAdapter.GetMemberCycleInfo(memberAddress,esusuCycleId);
    }
    
     function GetEsusuCycle(uint256 esusuCycleId) external view returns(uint256 CycleId, uint256 DepositAmount, 
                                                            uint256 PayoutIntervalSeconds, uint256 CycleState, 
                                                            uint256 TotalMembers, uint256 TotalAmountDeposited, uint256 TotalShares, 
                                                            uint256 TotalCycleDurationInSeconds, uint256 TotalCapitalWithdrawn, uint256 CycleStartTimeInSeconds,
                                                            uint256 TotalBeneficiaries, uint256 MaxMembers){
    
        return _esusuAdapter.GetEsusuCycle(esusuCycleId);                                                        
    }
    
    function StartEsusuCycle(uint256 esusuCycleId) external {
        _esusuAdapter.StartEsusuCycle(esusuCycleId);
    }
    
    function WithdrawROIFromEsusuCycle(uint256 esusuCycleId) external{
        _esusuAdapterWithdrawalDelegate.WithdrawROIFromEsusuCycle(esusuCycleId,msg.sender);
    }
    
    function WithdrawCapitalFromEsusuCycle(uint256 esusuCycleId) external{
        _esusuAdapterWithdrawalDelegate.WithdrawCapitalFromEsusuCycle(esusuCycleId,msg.sender);
    }
    
    function IsMemberEligibleToWithdrawROI(uint256 esusuCycleId, address member) external view returns(bool){
        return _esusuAdapterWithdrawalDelegate.IsMemberEligibleToWithdrawROI(esusuCycleId,member);
    }
    
    function IsMemberEligibleToWithdrawCapital(uint256 esusuCycleId, address member) external view returns(bool){
        return _esusuAdapterWithdrawalDelegate.IsMemberEligibleToWithdrawCapital(esusuCycleId,member);
    }

    function GetCurrentEsusuCycleId() external view returns(uint){
        return _esusuAdapter.GetCurrentEsusuCycleId();
    }

    function GetTotalDeposits() external view returns(uint)  {
        return _esusuAdapter.GetTotalDeposits();
    }
    modifier onlyOwner(){
        require(_owner == msg.sender, "Only owner can make this call");
        _;
    }


}