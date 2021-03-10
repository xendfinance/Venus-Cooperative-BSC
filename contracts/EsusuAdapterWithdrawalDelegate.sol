pragma solidity 0.6.6;

import "./IVBUSD.sol";
import "./IVenusLendingService.sol";
import "./OwnableService.sol";
import "./ITreasury.sol";
import "./ISavingsConfig.sol";
import "./ISavingsConfigSchema.sol";
import "./IRewardConfig.sol";
import "./IXendToken.sol";
import "./SafeMath.sol";
import "./IEsusuStorage.sol";
import "./IEsusuAdapter.sol";
import "./SafeERC20.sol";
import "./IERC20.sol";


contract EsusuAdapterWithdrawalDelegate is OwnableService, ISavingsConfigSchema {

        using SafeMath for uint256;

        using SafeERC20 for IERC20; 

        using SafeERC20 for IVBUSD; 

        event ROIWithdrawalEvent
        (
            uint256 date,
            address indexed member,  
            uint256 cycleId,
            uint256 amount       
        );

        event CapitalWithdrawalEvent
        (
            uint256 date,
            address indexed member,  
            uint256 cycleId,
            uint256 amount
        );

        event XendTokenReward (
          uint256 date,
          address indexed member,
          uint256 cycleId,
          uint256 amount
        );

        enum CycleStateEnum{
            Idle,               // Cycle has just been created and members can join in this state
            Active,             // Cycle has started and members can take their ROI
            Expired,            // Cycle Duration has elapsed and members can withdraw their capital as well as ROI
            Inactive            // Total beneficiaries is equal to Total members, so all members have withdrawn their Capital and ROI
        }

        event DepricateContractEvent(        
        uint256 date,
        address owner, 
        string reason
        );

        ITreasury immutable _treasuryContract;
        ISavingsConfig immutable _savingsConfigContract;
        IRewardConfig immutable _rewardConfigContract;
        IXendToken  immutable _xendTokenContract;
        string _feeRuleKey;
        uint256 _groupCreatorRewardPercent;

        IEsusuStorage immutable _esusuStorage;
        IEsusuAdapter immutable _esusuAdapterContract;
        IERC20 immutable _dai = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);             //  Pegged - BUSD on Binance Smart Chain
        IVBUSD immutable _yDai = IVBUSD(0x95c78222B3D6e262426483D42CfA53685A67Ab9D);            //  Venus BUSD Shares
        IVenusLendingService _iDaiLendingService;
        bool _isActive = true;
        uint256 _feePrecision = 10;     //  This determines the lower limit of the fee to be charged. With precsion of 10, it means our fee can have a precision of 0.1% and above
        uint256 _totalTokenReward;      //  This tracks the total number of token rewards distributed on the esusu 

        constructor(address payable serviceContract, address esusuStorageContract, address esusuAdapterContract,
                    string memory feeRuleKey, address treasuryContract, address rewardConfigContract, address xendTokenContract, address savingsConfigContract)public OwnableService(serviceContract){

            _esusuStorage = IEsusuStorage(esusuStorageContract);
            _esusuAdapterContract = IEsusuAdapter(esusuAdapterContract);
            _feeRuleKey = feeRuleKey;
            _treasuryContract = ITreasury(treasuryContract);
            _rewardConfigContract = IRewardConfig(rewardConfigContract);
            _xendTokenContract = IXendToken(xendTokenContract);
            _savingsConfigContract = ISavingsConfig(savingsConfigContract);

        }

        function UpdateDaiLendingService(address daiLendingServiceContractAddress) active onlyOwner external {
            _iDaiLendingService = IVenusLendingService(daiLendingServiceContractAddress);
        }
     function setGroupCreatorRewardPercent (uint percent) external onlyOwner {
            _groupCreatorRewardPercent = percent;
     }

        function UpdateFeePrecision(uint256 feePrecision) onlyOwner external{
            _feePrecision = feePrecision;
        }

        function GetTotalTokenRewardDistributed() external view returns(uint256){
            return _totalTokenReward;
        }
        /*
            This function allows members to withdraw their capital from the esusu cycle

            - Check if member can withdraw capital
            - Withdraw capital and increase TotalCapitalWithdrawn
                - Get the total balanceShares from the calling contract
                - Withdraw all the money from dai lending service
                - Send the member's deposited amount to his/her address
                - re-invest the remaining dai until all members have taken their capital, then we set the cycle inactive
            - Reward member with Xend Tokens
            - Add this member to the EsusuCycleCapitalMapping
            - Check if TotalCapitalWithdrawn == TotalAmountDeposited && if TotalMembers == TotalBeneficiaries, if yes, set the Cycle to Inactive

        */        
        function WithdrawCapitalFromEsusuCycle(uint256 esusuCycleId, address member) external active onlyOwnerAndServiceContract {

        //  Get Esusu Cycle Basic information
        (uint256 CycleId, uint256 DepositAmount, uint256 CycleState,uint256 TotalMembers,uint256 MaxMembers) = _esusuStorage.GetEsusuCycleBasicInformation(esusuCycleId);
        
        require(_isMemberEligibleToWithdrawCapital(esusuCycleId,member), "member is not eligible to withdraw");        
        //  Add member to capital withdrawn mapping

        //  Get the current yDaiSharesPerCycle and call the WithdrawByShares function on the daiLending Service
        uint256 yDaiSharesPerCycle = _esusuStorage.GetEsusuCycleTotalShares(esusuCycleId);


        //  transfer yDaiShares from the adapter contract to here
        _esusuAdapterContract.TransferYDaiSharesToWithdrawalDelegate(yDaiSharesPerCycle);        
        //  Get the yDaiSharesForContractBeforeWithdrawal 
        uint256 yDaiSharesForContractBeforeWithdrawal = _yDai.balanceOf(address(this));
        //  Withdraw the Dai. At this point, we have withdrawn  Dai Capital deposited by this member for this cycle and we will now transfer the dai capital to the member
        address daiLendingAdapterContractAddress = _iDaiLendingService.GetVenusLendingAdapterAddress();

        _yDai.approve(daiLendingAdapterContractAddress,yDaiSharesPerCycle);

        _iDaiLendingService.WithdrawByShares(DepositAmount,yDaiSharesPerCycle);
        
        //  Now the Dai is in this contract, transfer it to the member 
        _dai.safeTransfer(member, DepositAmount);
        
        //  Reward member with Xend Tokens
        _rewardMember(_esusuStorage.GetEsusuCycleDuration(esusuCycleId),member,DepositAmount,CycleId);
        
        //  Get the yDaiSharesForContractAfterWithdrawal 
        uint256 yDaiSharesForContractAfterWithdrawal = _yDai.balanceOf(address(this));
        
        require(yDaiSharesForContractBeforeWithdrawal > yDaiSharesForContractAfterWithdrawal, "yDai shares before withdrawal must be greater !!!");
        
        //  Update the total balanceShares for this cycle 
        uint256 cycleTotalShares = yDaiSharesPerCycle.sub(yDaiSharesForContractBeforeWithdrawal.sub(yDaiSharesForContractAfterWithdrawal));

        //  Add this member to the CycleToMemberWithdrawnCapitalMapping

        //  Create Member Capital Mapping
        _esusuStorage.CreateMemberCapitalMapping(esusuCycleId,member);        
        //  Increase total capital withdrawn 
        uint256 TotalCapitalWithdrawnInCycle = _esusuStorage.GetEsusuCycleTotalCapitalWithdrawn(CycleId).add(DepositAmount);
        
        //   Check if TotalCapitalWithdrawn == TotalAmountDeposited && if TotalMembers == TotalBeneficiaries, if yes, set the Cycle to Inactive

        if(TotalCapitalWithdrawnInCycle == _esusuStorage.GetEsusuCycleTotalAmountDeposited(esusuCycleId) && TotalMembers == _esusuStorage.GetEsusuCycleTotalBeneficiaries(esusuCycleId)){

            _esusuStorage.UpdateEsusuCycleState(esusuCycleId, uint(CycleStateEnum.Inactive));

            //  Since this cycle is inactive, send whatever Total shares Dai equivalent that is left to our treasury contract

            //  Withdraw DAI equivalent fof TotalShares

            _yDai.approve(daiLendingAdapterContractAddress,cycleTotalShares);
            _iDaiLendingService.WithdrawBySharesOnly(cycleTotalShares);
                   
            //  Now the Dai is in this contract, transfer it to the treasury contract 
            uint256 balance = _dai.balanceOf(address(this));
            _dai.approve(address(_treasuryContract),balance);
            _treasuryContract.depositToken(address(_dai));

        }else{

            //  Since we have not withdrawn all the capital, then Send the yDai shares back to the adapter contract,
            //  this contract should not hold any coins
            _yDai.safeTransfer(address(_esusuAdapterContract),_yDai.balanceOf(address(this)));

        }

        //  Update Esusu Cycle Information For Capital Withdrawal
        _esusuStorage.UpdateEsusuCycleDuringCapitalWithdrawal(CycleId, cycleTotalShares,TotalCapitalWithdrawnInCycle);

        //  emit event
        emit CapitalWithdrawalEvent(now, member, esusuCycleId,DepositAmount);

    }

      /*
        Assumption:
        - We assume even distribution of Overall accumulated ROI among members of the group when a member places a withdrawal request at a time inverval
          greater than members in the previous position who have not placed a withdrawal request.

        This function sends all ROI generated within an Esusu Cycle Payout Interval to a particular member

        - Check if member is eligible to withdraw
        - Get the price per full share from Dai Lending Service\
        - Get overall DAI => yDai balanceShares * pricePerFullShare (NOTE: value is in 1e36)
        - Get ROI => overall Dai - Total Deposited Dai in this esusu cycle
        - Implement our derived equation to determine what ROI will be allocated to this member who is withdrawing
        - Deduct fees from Member's ROI
        - Equation Parameters
            - Ta => Total available time in seconds
            - Bt => Total Time Interval for beneficiaries in this cycle in seconds
            - Tnow => Current Time in seconds
            - T => Cycle PayoutIntervalSeconds
            - Troi => Total accumulated ROI
            - Mroi => Member ROI    
                    
            Equations - Update from CertiK Audit
            - Bt = number of beneficiaries
            - Ta = Total Members In Cycle - Bt
            - Troi = ((balanceShares * pricePerFullShare ) - TotalDeposited - TotalCapitalWithdrawn)
            - Mroi = (Total accumulated ROI at Tnow) / (Ta) 
        NOTE: As members withdraw their funds, the yDai balanceShares will change and we will be updating the TotalShares with this new value
        at all times till TotalShares becomes approximately zero when all amounts have been withdrawn including capital invested

        - Track the yDai shares that belong to this cycle using the derived equation below for withdraw operation
            - yDaiSharesPerCycle = Current yDai Shares in the cycle - Change in yDaiSharesForContract
            - Change in yDaiSharesForContract = yDai.balanceOf(address(this)) before withdraw operation - yDai.balanceOf(address(this)) after withdraw operation

    */
        function WithdrawROIFromEsusuCycle(uint256 esusuCycleId, address member)  external active onlyOwnerAndServiceContract {
        
        uint256 totalMembers = _esusuStorage.GetTotalMembersInCycle(esusuCycleId);

        bool isMemberEligibleToWithdraw = _isMemberEligibleToWithdrawROI(esusuCycleId,member);

        require(isMemberEligibleToWithdraw, "Member cannot withdraw at this time");
        
        uint256 currentBalanceShares = _esusuStorage.GetEsusuCycleTotalShares(esusuCycleId);
        
        // uint256 pricePerFullShare = _iDaiLendingService.GetPricePerFullShare();
        
        // uint256 overallGrossDaiBalance = currentBalanceShares.mul(_iDaiLendingService.GetPricePerFullShare()).div(1e18);
        uint256 overallGrossDaiBalance = currentBalanceShares.mul(_iDaiLendingService.GetPricePerFullShare());

        uint256 CycleId = esusuCycleId;

        // address memberAddress = member;

        //  Implement our derived equation to get the amount of Dai to transfer to the member as ROI
        uint256 Bt = _esusuStorage.GetEsusuCycleTotalBeneficiaries(esusuCycleId);

        uint256 Ta = totalMembers.sub(Bt);
        uint256 Troi = overallGrossDaiBalance.sub(_esusuStorage.GetEsusuCycleTotalAmountDeposited(esusuCycleId).sub(_esusuStorage.GetEsusuCycleTotalCapitalWithdrawn(esusuCycleId)));

        uint Mroi = Troi.div(Ta);

        //  Get the current yDaiSharesPerCycle and call the WithdrawByShares function on the daiLending Service
        // uint yDaiSharesPerCycle = currentBalanceShares;

        //  transfer yDaiShares from the adapter contract to here
        _esusuAdapterContract.TransferYDaiSharesToWithdrawalDelegate(currentBalanceShares);

        //  Get the yDaiSharesForContractBeforeWithdrawal
        uint yDaiSharesForContractBeforeWithdrawal = _yDai.balanceOf(address(this));

        //  Withdraw the Dai. At this point, we have withdrawn the Dai ROI for this member and the dai ROI is in this contract, we will now transfer it to the member
        address daiLendingAdapterContractAddress = _iDaiLendingService.GetVenusLendingAdapterAddress();

        //  Before this function is called, we will have triggered a transfer of yDaiShares from the adapter to this withdrawal contract
        _yDai.approve(daiLendingAdapterContractAddress,currentBalanceShares);
        _iDaiLendingService.WithdrawByShares(Mroi,currentBalanceShares);


        //  Now the Dai is in this contract, transfer the net ROI to the member and fee to treasury contract
        sendROI(Mroi,member,CycleId);
          
        //  Get the yDaiSharesForContractAfterWithdrawal 
        uint256 yDaiSharesForContractAfterWithdrawal = _yDai.balanceOf(address(this));
        
        require(yDaiSharesForContractBeforeWithdrawal > yDaiSharesForContractAfterWithdrawal, "yDai shares before withdrawal must be greater !!!");
        
        //  Update the total balanceShares for this cycle 
        uint256 totalShares = currentBalanceShares.sub(yDaiSharesForContractBeforeWithdrawal.sub(yDaiSharesForContractAfterWithdrawal));
        
        //  Increase total number of beneficiaries by 1
        uint256 totalBeneficiaries = _esusuStorage.GetEsusuCycleTotalBeneficiaries(CycleId).add(1);
        

        /*

            - Check whether the TotalCycleDuration has elapsed, if that is the case then this cycle has expired
            - If cycle has expired then we move the left over yDai to treasury
        */

        if(now > _esusuStorage.GetEsusuCycleDuration(CycleId)){

            _esusuStorage.UpdateEsusuCycleState(CycleId, uint(CycleStateEnum.Expired));
        }

        //  Update Esusu Cycle During ROI withdrawal
        _esusuStorage.UpdateEsusuCycleDuringROIWithdrawal(CycleId, totalShares,totalBeneficiaries);

        //  Send the yDai shares back to the adapter contract, this contract should not hold any coins
        _yDai.safeTransfer(address(_esusuAdapterContract),_yDai.balanceOf(address(this)));
        
        //  emit event 
        _emitROIWithdrawalEvent(member,Mroi,CycleId);
    }

    
    /*
        This gets the fee percentage from the fee contract, deducts the fee and sends to treasury contract

        For now let us assume fee percentage is 0.1%
        - Get the fee
        - Send the net ROI in dai to member
        - Send the fee to the treasury
        - Add member to beneficiary mapping
    */
    function sendROI(uint256 Mroi, address memberAddress, uint256 esusuCycleId) internal{       
        //  get feeRate from fee contract

        (uint256 minimum, uint256 maximum, uint256 exact, bool applies, RuleDefinition e)  = _savingsConfigContract.getRuleSet(_feeRuleKey);
        /**
            fee = ( (exact/precision)/(100) * roi)
         */

        uint256 feeRate = exact; 
        uint256 fee = Mroi.mul(feeRate).div(_feePrecision.mul(100));
        
        //  Deduct the fee
        uint256 memberROINet = Mroi.sub(fee); 
        

         //  Add member to beneficiary mapping

        _esusuStorage.CreateEsusuCycleToBeneficiaryMapping(esusuCycleId,memberAddress,memberROINet); 


        //  Send ROI to member 
        _dai.safeTransfer(memberAddress, memberROINet);

        uint256 creatorReward =  fee.mul(_groupCreatorRewardPercent).div(_feePrecision.mul(100));

        uint256 finalFee = fee.sub(creatorReward);
        //  Send deducted fee to treasury
        //  Approve the treasury contract
        _dai.approve(address(_treasuryContract),finalFee);
        _treasuryContract.depositToken(address(_dai));

        address cycleOwner = _esusuStorage.GetCycleOwner(esusuCycleId);
        
        _dai.safeTransfer(cycleOwner, creatorReward);


    }

        /*
        This function checks whether the user can withdraw at the time at which the user is making this call

        - Check if cycle is valid
        - Check if cycle is in active state
        - Check if member is in cycle
        - Check if member is a beneficiary
        - Calculate member withdrawal time
        - Check if member can withdraw at this time
    */
    function IsMemberEligibleToWithdrawROI(uint256 esusuCycleId, address member) active external view returns(bool){
        
        return _isMemberEligibleToWithdrawROI(esusuCycleId,member);

    }

    /*
        This function checks whether the user can withdraw capital after the Esusu Cycle is complete.

        The cycle must be in an inactive state before capital can be withdrawn
    */
    function IsMemberEligibleToWithdrawCapital(uint256 esusuCycleId, address member) active external view returns(bool){
        
        return _isMemberEligibleToWithdrawCapital(esusuCycleId,member);

    }
    
    function _isMemberEligibleToWithdrawROI(uint256 esusuCycleId, address member) internal view returns(bool){
        
        //  Get Current EsusuCycleId
        uint256 currentEsusuCycleId = _esusuStorage.GetEsusuCycleId();        
        
        require(esusuCycleId != 0 && esusuCycleId <= currentEsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        uint256 cycleState = _esusuStorage.GetEsusuCycleState(esusuCycleId);
        


        require(cycleState == uint(CycleStateEnum.Active) || cycleState == uint(CycleStateEnum.Expired), "Cycle must be in active or expired state");

        require(_isMemberInCycle(member,esusuCycleId), "Member is not in this cycle");
        
        require(!_isMemberABeneficiaryInCycle(member,esusuCycleId), "Member is already a beneficiary");
        
        uint256 memberWithdrawalTime = _calculateMemberWithdrawalTime(esusuCycleId,member); 
        
        return now > memberWithdrawalTime;
        
    }
    
    function _isMemberEligibleToWithdrawCapital(uint256 esusuCycleId, address member) internal view returns(bool){
        
        //  Get Current EsusuCycleId
        uint256 currentEsusuCycleId = _esusuStorage.GetEsusuCycleId();
        
        require(esusuCycleId != 0 && esusuCycleId <= currentEsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        uint256 cycleState = _esusuStorage.GetEsusuCycleState(esusuCycleId);
        
        require(cycleState == uint(CycleStateEnum.Expired), "Cycle must be in Expired state for you to withdraw capital");

        require(_isMemberInCycle(member,esusuCycleId), "Member is not in this cycle");
        
        require(_isMemberABeneficiaryInCycle(member,esusuCycleId), "Member must be a beneficiary before you can withdraw capital");

        require(!_isMemberInWithdrawnCapitalMapping(member,esusuCycleId), "Member can't withdraw capital twice");

        return true;

    }
    
    function _isMemberInCycle(address memberAddress,uint256 esusuCycleId ) internal view returns(bool){
        
        return _esusuStorage.IsMemberInCycle(memberAddress,esusuCycleId);
    }
    
    function _isMemberABeneficiaryInCycle(address memberAddress,uint256 esusuCycleId ) internal view returns(bool){
        
        uint256 amount = _esusuStorage.GetMemberCycleToBeneficiaryMapping(esusuCycleId, memberAddress);

        //  If member has received money from this cycle, the amount recieved should be greater than 0

        return amount > 0;
    }
    
    function _isMemberInWithdrawnCapitalMapping(address memberAddress,uint256 esusuCycleId ) internal view returns(bool){
        
        uint256 amount = _esusuStorage.GetMemberWithdrawnCapitalInEsusuCycle(esusuCycleId, memberAddress);
        //  If member has withdrawn capital from this cycle, the amount recieved should be greater than 0
        return amount > 0;
    }
    
    function _calculateMemberWithdrawalTime(uint256 cycleId, address member) internal view returns(uint){
      
        return _esusuStorage.CalculateMemberWithdrawalTime(cycleId,member);
    }
    
    function _emitROIWithdrawalEvent(address member,uint256 Mroi, uint256 esusuCycleId) internal{

        emit ROIWithdrawalEvent(now, member,esusuCycleId,Mroi);
    }

    function _emitXendTokenReward(address member, uint amount, uint esusuCycleId) internal {
      emit XendTokenReward(now, member, esusuCycleId, amount);
    }

    function _rewardMember(uint totalCycleTime, address member, uint amount, uint esusuCycleId) internal {

        uint256 reward = _rewardConfigContract.CalculateEsusuReward(totalCycleTime, amount);

        // get Xend Token contract and mint token for member
        _xendTokenContract.mint(payable(member), reward);

        //  update the xend token reward for the member
        _esusuStorage.UpdateMemberToXendTokeRewardMapping(member,reward);

        //  increase the total number of xend token rewards distributed
        _totalTokenReward = _totalTokenReward.add(reward);

        _emitXendTokenReward(member, reward, esusuCycleId);
    }

    function DepricateContract(string calldata reason) external onlyOwner{
        //  set _isActive to false
        _isActive = false;

        DepricateContractEvent(now, owner, reason);

    }

    modifier active(){
        require(_isActive == true, "This contract is depricated, use new version of contract");
        _;
    }
}
