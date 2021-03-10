pragma solidity 0.6.6;

import "./IVBUSD.sol";
import "./IVenusLendingService.sol";
import "./OwnableService.sol";
import "./ISavingsConfig.sol";
import "./ISavingsConfigSchema.sol";
import "./IGroups.sol";
import "./SafeMath.sol";
import "./IEsusuStorage.sol";
import "./SafeERC20.sol";
import "./IERC20.sol";


contract EsusuAdapter is OwnableService, ISavingsConfigSchema {
    
    using SafeMath for uint256;

    using SafeERC20 for IERC20; 

    using SafeERC20 for IVBUSD; 

    /*
        Events to emit
        1. Creation of Esusu Cycle
        2. Joining of Esusu Cycle
        3. Starting of Esusu Cycle
        4. Withdrawal of ROI
        5. Withdrawal of Capital
    */
    event CreateEsusuCycleEvent
    (
        uint256 date,
        uint256 indexed cycleId,
        uint256 depositAmount,
        address  Owner,
        uint256 payoutIntervalSeconds,
        CurrencyEnum currency,
        string currencySymbol,
        uint256 cycleState
    );

    event DepricateContractEvent(
        
        uint256 date,
        address owner, 
        string reason,
        uint256 yDaiSharesTransfered
    );
    event JoinEsusuCycleEvent
    (
        uint256 date,
        address indexed member,   
        uint256 memberPosition,
        uint256 totalAmountDeposited,
        uint256 cycleId
    );
    
    event StartEsusuCycleEvent
    (
        uint256 date,
        uint256 totalAmountDeposited,
        uint256 totalCycleDuration,
        uint256 totalShares,
        uint256 indexed cycleId
    );

    /*  Enum definitions */
    enum CurrencyEnum {Dai}

    enum CycleStateEnum {
        Idle, // Cycle has just been created and members can join in this state
        Active, // Cycle has started and members can take their ROI
        Expired, // Cycle Duration has elapsed and members can withdraw their capital as well as ROI
        Inactive // Total beneficiaries is equal to Total members, so all members have withdrawn their Capital and ROI
    }

    
    //  Member variables
    ISavingsConfig _savingsConfigContract;
    IGroups immutable _groupsContract;

    IVenusLendingService _iDaiLendingService;
    IERC20 immutable _dai = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);             //  Pegged - BUSD on Binance Smart Chain
    IVBUSD immutable _yDai = IVBUSD(0x95c78222B3D6e262426483D42CfA53685A67Ab9D);            //  Venus BUSD Shares
    IEsusuStorage _esusuStorage;
    address _delegateContract;
    bool _isActive = true;
    

    constructor (address payable serviceContract, 
                     address groupsContract,
                    address esusuStorageContract) public OwnableService(serviceContract){
        _groupsContract = IGroups(groupsContract);
        _esusuStorage = IEsusuStorage(esusuStorageContract);
    }

    function UpdateDaiLendingService(address daiLendingServiceContractAddress)
        external
        onlyOwner
        active
    {
        _iDaiLendingService = IVenusLendingService(
            daiLendingServiceContractAddress
        );
    }

    function UpdateEsusuAdapterWithdrawalDelegate(address delegateContract)
        external
        onlyOwner
        active
    {
        _delegateContract = delegateContract;
    }

    /*
        NOTE: startTimeInSeconds is the time at which when elapsed, any one can start the cycle
        -   Creates a new EsusuCycle
        -   Esusu Cycle can only be created by the owner of the group
    */
    
    function CreateEsusu(uint256 groupId, uint256 depositAmount, uint256 payoutIntervalSeconds,uint256 startTimeInSeconds, address owner, uint256 maxMembers) external active onlyOwnerAndServiceContract {
        //  Get Current EsusuCycleId
        uint256 currentEsusuCycleId = _esusuStorage.GetEsusuCycleId();

        // Get Group information by Id
        (uint256 id, string memory name, string memory symbol, address creatorAddress) = GetGroupInformationById(groupId);
        
        require(owner == creatorAddress, "EsusuCycle can only be created by group owner");
        
        _esusuStorage.CreateEsusuCycleMapping(groupId,depositAmount,payoutIntervalSeconds,startTimeInSeconds,owner,maxMembers);
        
        //  emit event
        emit CreateEsusuCycleEvent(now, currentEsusuCycleId, depositAmount, owner, payoutIntervalSeconds,CurrencyEnum.Dai,"Dai Stablecoin",_esusuStorage.GetEsusuCycleState(currentEsusuCycleId));
        
    }

    //  Join a particular Esusu Cycle
    /*
        - Check if the cycle ID is valid
        - Check if the cycle is in Idle state, that is the only state a member can join
        - Check if member is already in Cycle
        - Ensure member has approved this contract to transfer the token on his/her behalf
        - If member has enough balance, transfer the tokens to this contract else bounce
        - Increment the total deposited amount in this cycle and total deposited amount for the member cycle struct
        - Increment the total number of Members that have joined this cycle
    */
    
    // function JoinEsusu(uint256 esusuCycleId, address member) external onlyOwnerAndServiceContract active {
    //     //  Get Current EsusuCycleId
    //     uint256 currentEsusuCycleId = _esusuStorage.GetEsusuCycleId();
        
    //     //  Check if the cycle ID is valid
    //     require(
    //         esusuCycleId > 0 && esusuCycleId <= currentEsusuCycleId,
    //         "Cycle ID must be within valid EsusuCycleId range"
    //     );

    //     //  Get the Esusu Cycle struct
        
    //     (uint256 CycleId, uint256 DepositAmount, uint256 CycleState,uint256 TotalMembers,uint256 MaxMembers) = _esusuStorage.GetEsusuCycleBasicInformation(esusuCycleId);
    //     //  If cycle is not in Idle State, bounce 
    //     require( CycleState == uint(CycleStateEnum.Idle), "Esusu Cycle must be in Idle State before you can join");

        
    //     //  If cycle is filled up, bounce 

    //     require(TotalMembers < MaxMembers, "Esusu Cycle is filled up, you can't join");
        
    //     //  check if member is already in this cycle 
    //     require(!_isMemberInCycle(member,esusuCycleId), "Member can't join same Esusu Cycle more than once");
        
    //     //  If user does not have enough Balance, bounce. For now we use Dai as default
    //     uint256 memberBalance = _dai.balanceOf(member);
        
    //     require(memberBalance >= DepositAmount, "Balance must be greater than or equal to Deposit Amount");
        
        
    //     //  If user balance is greater than or equal to deposit amount then transfer from member to this contract
    //     //  NOTE: approve this contract to withdraw before transferFrom can work
    //     _dai.safeTransferFrom(member, address(this), DepositAmount);
        
    //     //  Increment the total deposited amount in this cycle
    //     uint256 totalAmountDeposited = _esusuStorage.IncreaseTotalAmountDepositedInCycle(esusuCycleId,DepositAmount);
        
        
    //     _esusuStorage.CreateMemberAddressToMemberCycleMapping(member,esusuCycleId);
        
    //     //  Increase TotalMembers count by 1
    //     _esusuStorage.IncreaseTotalMembersInCycle(esusuCycleId);
    //     //  Create the position of the member in the cycle
    //     _esusuStorage.CreateMemberPositionMapping(CycleId, member);
    //     //  Create mapping to track the Cycles a member belongs to by index and by ID
    //     _esusuStorage.CreateMemberToCycleIndexToCycleIDMapping(member, CycleId);

    //     //  emit event
    //     emit JoinEsusuCycleEvent(
    //         now,
    //         member,
    //         TotalMembers,
    //         totalAmountDeposited,
    //         esusuCycleId
    //     );
    // }

    function JoinEsusu(uint esusuCycleId, address member) public onlyOwnerAndServiceContract active {
        //  Get Current EsusuCycleId
        uint256 currentEsusuCycleId = _esusuStorage.GetEsusuCycleId();
        
        //  Check if the cycle ID is valid
        require(esusuCycleId > 0 && esusuCycleId <= currentEsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        //  Get the Esusu Cycle struct
        
        (uint256 CycleId, uint256 DepositAmount, uint256 CycleState,uint256 TotalMembers,uint256 MaxMembers) = _esusuStorage.GetEsusuCycleBasicInformation(esusuCycleId);
        //  If cycle is not in Idle State, bounce 
        require( CycleState == uint(CycleStateEnum.Idle), "Esusu Cycle must be in Idle State before you can join");

        //  If cycle is filled up, bounce 

        require(TotalMembers < MaxMembers, "Esusu Cycle is filled up, you can't join");
        
        //  check if member is already in this cycle 
        require(!_isMemberInCycle(member,esusuCycleId), "Member can't join same Esusu Cycle more than once");
        
        //  If user does not have enough Balance, bounce. For now we use Dai as default
        uint256 memberBalance = _dai.balanceOf(member);
        
        require(memberBalance >= DepositAmount, "Balance must be greater than or equal to Deposit Amount");
        
        
        //  If user balance is greater than or equal to deposit amount then transfer from member to this contract
        //  NOTE: approve this contract to withdraw before transferFrom can work
        _dai.safeTransferFrom(member, address(this), DepositAmount);
        
        //  Increment the total deposited amount in this cycle
        uint256 totalAmountDeposited = _esusuStorage.IncreaseTotalAmountDepositedInCycle(CycleId,DepositAmount);
        
        
       _esusuStorage.CreateMemberAddressToMemberCycleMapping(
            member,
            esusuCycleId
        );

        //  Increase TotalMembers count by 1
        _esusuStorage.IncreaseTotalMembersInCycle(esusuCycleId);
        //  Create the position of the member in the cycle
        _esusuStorage.CreateMemberPositionMapping(CycleId, member);
        //  Create mapping to track the Cycles a member belongs to by index and by ID
        _esusuStorage.CreateMemberToCycleIndexToCycleIDMapping(member, CycleId);

        //  Get  the BUSD deposited for this cycle by this user: DepositAmount
        
        //  Get the balance of fBUSDSharesForContract before save operation for this user
        uint fBUSDSharesForContractBeforeSave = _yDai.balanceOf(address(this));
        
        //  Invest the dai in Yearn Finance using Dai Lending Service.
        
        //  NOTE: yDai will be sent to this contract
        //  Transfer dai from this contract to dai lending adapter and then call a new save function that will not use transferFrom internally
        //  Approve the daiLendingAdapter so it can spend our Dai on our behalf 
        address daiLendingAdapterContractAddress = _iDaiLendingService.GetVenusLendingAdapterAddress();
        _dai.approve(daiLendingAdapterContractAddress,DepositAmount);
        
        _iDaiLendingService.Save(DepositAmount);
        
        //  Get the balance of fBUSDSharesForContract after save operation
        uint fBUSDSharesForContractAfterSave = _yDai.balanceOf(address(this));
        
        
        //  Save fBUSD Total balanceShares for this member
        uint sharesForMember = fBUSDSharesForContractAfterSave.sub(fBUSDSharesForContractBeforeSave);
        
        //  Increase TotalDeposits made to this contract 

        _esusuStorage.IncreaseTotalDeposits(DepositAmount);

        //  Update Esusu Cycle State, total cycle duration, total shares  and  cycle start time, 
        _esusuStorage.UpdateEsusuCycleSharesDuringJoin(CycleId, sharesForMember);

        //  emit event 
        emit JoinEsusuCycleEvent(now, member,TotalMembers, totalAmountDeposited,CycleId);
    }

    /*
        - Check if the Id is a valid ID
        - Check if the cycle is in Idle State
        - Anyone  can start that cycle -
        - Get the total number of members and then multiply by the time interval in seconds to get the total time this Cycle will last for
        - Set the Cycle start time to now 
        - Take everyones deposited DAI from this Esusu Cycle and then invest through Yearn 
        - Track the yDai shares that belong to this cycle using the derived equation below for save/investment operation
            - yDaiSharesPerCycle = Change in yDaiSharesForContract + Current yDai Shares in the cycle
            - Change in yDaiSharesForContract = yDai.balanceOf(address(this) after save operation - yDai.balanceOf(address(this) after before operation
    */
    
    // function StartEsusuCycle(uint256 esusuCycleId) external onlyOwnerAndServiceContract active{
        
    //     //  Get Current EsusuCycleId
    //     uint256 currentEsusuCycleId = _esusuStorage.GetEsusuCycleId();
        
    //     //  Get Esusu Cycle Basic information
    //     (uint256 CycleId, uint256 DepositAmount, uint256 CycleState,uint256 TotalMembers,uint256 MaxMembers) = _esusuStorage.GetEsusuCycleBasicInformation(esusuCycleId);

    //     //  Get Esusu Cycle Total Shares
    //     (uint256 EsusuCycleTotalShares) = _esusuStorage.GetEsusuCycleTotalShares(esusuCycleId);
        
        
    //     //  Get Esusu Cycle Payout Interval 
    //     (uint256 EsusuCyclePayoutInterval) = _esusuStorage.GetEsusuCyclePayoutInterval(esusuCycleId);
        
        
    //     //  If cycle ID is valid, else bonunce
    //     require(esusuCycleId != 0 && esusuCycleId <= currentEsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        

    //     require(
    //         now > _esusuStorage.GetEsusuCycleStartTime(esusuCycleId),
    //         "Cycle can only be started when start time has elapsed"
    //     );

    //     //  Calculate Cycle LifeTime in seconds
    //     uint256 toalCycleDuration = EsusuCyclePayoutInterval * TotalMembers;

    //     //  Get all the dai deposited for this cycle
    //     uint256 esusuCycleBalance = _esusuStorage.GetEsusuCycleTotalAmountDeposited(esusuCycleId);
        
    //     //  Get the balance of yDaiSharesForContract before save opration
    //     uint256 yDaiSharesForContractBeforeSave = _yDai.balanceOf(address(this));
        
    //     //  Invest the dai in Yearn Finance using Dai Lending Service.

    //     //  NOTE: yDai will be sent to this contract
    //     //  Transfer dai from this contract to dai lending adapter and then call a new save function that will not use transferFrom internally
    //     //  Approve the daiLendingAdapter so it can spend our Dai on our behalf
    //     address daiLendingAdapterContractAddress = _iDaiLendingService
    //         .GetVenusLendingAdapterAddress();
    //     _dai.approve(daiLendingAdapterContractAddress, esusuCycleBalance);

    //     _iDaiLendingService.Save(esusuCycleBalance);

    //     //  Get the balance of yDaiSharesForContract after save operation
    //     uint256 yDaiSharesForContractAfterSave = _yDai.balanceOf(address(this));
        
        
    //     //  Save yDai Total balanceShares
    //     uint256 totalShares = yDaiSharesForContractAfterSave.sub(yDaiSharesForContractBeforeSave).add(EsusuCycleTotalShares);
        
    //     //  Increase TotalDeposits made to this contract 

    //     _esusuStorage.IncreaseTotalDeposits(esusuCycleBalance);

    //     //  Update Esusu Cycle State, total cycle duration, total shares  and  cycle start time,
    //     _esusuStorage.UpdateEsusuCycleDuringStart(
    //         CycleId,
    //         uint256(CycleStateEnum.Active),
    //         toalCycleDuration,
    //         totalShares,
    //         now
    //     );

    //     //  emit event
    //     emit StartEsusuCycleEvent(
    //         now,
    //         esusuCycleBalance,
    //         toalCycleDuration,
    //         totalShares,
    //         esusuCycleId
    //     );
    // }
    
    function StartEsusuCycle(uint esusuCycleId) public onlyOwnerAndServiceContract active{
        
        //  Get Current EsusuCycleId
        uint256 currentEsusuCycleId = _esusuStorage.GetEsusuCycleId();
        
        //  Get Esusu Cycle Basic information
        (uint256 CycleId, uint256 DepositAmount, uint256 CycleState,uint256 TotalMembers,uint256 MaxMembers) = _esusuStorage.GetEsusuCycleBasicInformation(esusuCycleId);

        //  Get Esusu Cycle Total Shares
        (uint256 EsusuCycleTotalShares) = _esusuStorage.GetEsusuCycleTotalShares(esusuCycleId);
        
        
        //  Get Esusu Cycle Payout Interval 
        (uint256 EsusuCyclePayoutInterval) = _esusuStorage.GetEsusuCyclePayoutInterval(esusuCycleId);
        
        
        //  If cycle ID is valid, else bonunce
        require(esusuCycleId != 0 && esusuCycleId <= currentEsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        require(now > _esusuStorage.GetEsusuCycleStartTime(esusuCycleId),"Cycle can only be started when start time has elapsed");

        require(CycleState == uint(CycleStateEnum.Idle), "Cycle can only be started when in Idle state");
           
        require(TotalMembers >= 2, "Cycle can only be started with 2 or more members" );

        //  Calculate Cycle LifeTime in seconds
        uint256 toalCycleDuration = EsusuCyclePayoutInterval * TotalMembers;

        //  Get all the dai deposited for this cycle
        uint256 esusuCycleBalance = _esusuStorage.GetEsusuCycleTotalAmountDeposited(esusuCycleId);
                
        //  Update Esusu Cycle State, total cycle duration, total shares  and  cycle start time, 
        _esusuStorage.UpdateEsusuCycleDuringStart(CycleId,uint(CycleStateEnum.Active),toalCycleDuration,EsusuCycleTotalShares,now);
        
        //  emit event 
        emit StartEsusuCycleEvent(now,esusuCycleBalance, toalCycleDuration,
                                    EsusuCycleTotalShares,esusuCycleId);
    }
  
    function GetMemberCycleInfo(address memberAddress, uint256 esusuCycleId) active external view returns(uint256 CycleId, address MemberId, uint256 TotalAmountDepositedInCycle, uint256 TotalPayoutReceivedInCycle, uint256 memberPosition) {
        
        return _esusuStorage.GetMemberCycleInfo(memberAddress, esusuCycleId);
    }

    function GetEsusuCycle(uint256 esusuCycleId) external view returns(uint256 CycleId, uint256 DepositAmount, 
                                                            uint256 PayoutIntervalSeconds, uint256 CycleState, 
                                                            uint256 TotalMembers, uint256 TotalAmountDeposited, uint256 TotalShares, 
                                                            uint256 TotalCycleDurationInSeconds, uint256 TotalCapitalWithdrawn, uint256 CycleStartTimeInSeconds,
                                                            uint256 TotalBeneficiaries, uint256 MaxMembers){
        
        return _esusuStorage.GetEsusuCycle(esusuCycleId);
    }

    function GetDaiBalance(address member)
        external
        view
        active
        returns (uint256)
    {
        return _dai.balanceOf(member);
    }

    function GetYDaiBalance(address member)
        external
        view
        active
        returns (uint256)
    {
        return _yDai.balanceOf(member);
    }
    
    
    
    function GetTotalDeposits() active external view returns(uint)  {
        return _esusuStorage.GetTotalDeposits();
    }

    
    function GetCurrentEsusuCycleId() active external view returns(uint){
        
        return _esusuStorage.GetEsusuCycleId();
    }
    
    function _isMemberInCycle(address memberAddress,uint256 esusuCycleId ) internal view returns(bool){
        
        return _esusuStorage.IsMemberInCycle(memberAddress,esusuCycleId);
    }
    
    function _isMemberABeneficiaryInCycle(address memberAddress,uint256 esusuCycleId ) internal view returns(bool){

        return _esusuStorage.GetMemberCycleToBeneficiaryMapping(esusuCycleId, memberAddress) > 0;
    }
    
    function _isMemberInWithdrawnCapitalMapping(address memberAddress,uint256 esusuCycleId ) internal view returns(bool){
        
        return _esusuStorage.GetMemberWithdrawnCapitalInEsusuCycle(esusuCycleId, memberAddress) > 0;
    }

    /*
        - Get the group index by name
        - Get the group information by index
    */
    function GetGroupInformationByName(string calldata name) active external view returns (uint256 groupId, string memory groupName, string memory groupSymbol, address groupCreatorAddress){
        
        //  Get the group index by name
        (, uint256 index ) = _groupsContract.getGroupIndexerByName(name);
        
        //  Get the group id by index and return 

        return _groupsContract.getGroupByIndex(index);
    }

    /*
        - Get the group information by Id
    */
    function GetGroupInformationById(uint256 id) active public view returns (uint256 groupId, string memory groupName, string memory groupSymbol, address groupCreatorAddress){
        
        //  Get the group id by index and return 

        return _groupsContract.getGroupById(id);
    }

    /*
        - Creates the group
        - returns the ID and other information
    */
    function CreateGroup(string calldata name, string calldata symbol, address groupCreator) active external {
        
           _groupsContract.createGroup(name,symbol,groupCreator);
           
    }
    
    function TransferYDaiSharesToWithdrawalDelegate(uint256 amount) external active onlyOwnerAndDelegateContract {
        
        _yDai.safeTransfer(_delegateContract, amount);
    }

    function DepricateContract(
        address newEsusuAdapterContract,
        string calldata reason
    ) external onlyOwner {
        //  set _isActive to false
        _isActive = false;
        
        uint256 yDaiSharesBalance = _yDai.balanceOf(address(this));

        //  Send yDai shares to the new contract and halt operations of this contract
        _yDai.safeTransfer(newEsusuAdapterContract, yDaiSharesBalance);
        
        DepricateContractEvent(now, owner, reason, yDaiSharesBalance);

    }

    modifier onlyOwnerAndDelegateContract() {
        require(
            msg.sender == owner || msg.sender == _delegateContract,
            "Unauthorized access to contract"
        );
        _;
    }
    
    modifier active(){
        require(_isActive, "This contract is depricated, use new version of contract");
        _;
    }
}

