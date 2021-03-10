// SPDX-License-Identifier: MIT

pragma solidity 0.6.6;
import "./ISavingsConfig.sol";
import "./ITreasury.sol";
// import "./Ownable.sol";
import "./IGroups.sol";
import "./SafeERC20.sol";
import "./ICycle.sol";
import "./IVBUSD.sol";
import "./IGroupSchema.sol";
import "./IVenusLendingService.sol";
import "./ReentrancyGuard.sol";
import "./IERC20.sol";
// import "./Address.sol";
import "./IRewardConfig.sol";
import "./SafeMath.sol";
import "./IXendToken.sol";

contract XendFinanceGroupContainer_Yearn_V1 is IGroupSchema {
    struct CycleDepositResult {
        Group group;
        Member member;
        GroupMember groupMember;
        CycleMember cycleMember;
        uint256 underlyingAmountDeposited;
    }

    struct WithdrawalResolution {
        uint256 amountToSendToMember;
        uint256 amountToSendToTreasury;
    }

    event XendTokenReward(uint256 date, address indexed member, uint256 amount);

    event UnderlyingAssetDeposited(
        uint256 indexed cycleId,
        address payable indexed memberAddress,
        uint256 groupId,
        uint256 underlyingAmount,
        address indexed tokenAddress
    );

    event DerivativeAssetWithdrawn(
        uint256 indexed cycleId,
        address payable indexed memberAddress,
        uint256 underlyingAmount,
        address tokenAddress
    );

    event GroupCreated(
        uint256 indexed groupId,
        address payable indexed groupCreator
    );

    event CycleCreated(
        uint256 indexed cycleId,
        uint256 maximumSlots,
        bool hasMaximumSlots,
        uint256 stakeAmount,
        uint256 expectedCycleStartTimeStamp,
        uint256 cycleDuration
    );

    event MemberJoinedCycle(
        uint256 indexed cycleId,
        address payable indexed memberAddress,
        uint256 groupId
    );

    event MemberJoinedGroup(address payable memberAddress, uint256 groupId);

    event CycleStartedEvent(
        uint256 indexed cycleId,
        uint256 indexed blockTimeStamp,
        uint256 blockNumber,
        uint256 totalUnderlyingAmount
    );

    IVenusLendingService lendingService;
    IERC20 _busd;
    IGroups groupStorage;
    ICycles cycleStorage;
    ITreasury treasury;
    ISavingsConfig savingsConfig;
    IRewardConfig rewardConfig;
    IXendToken xendToken;
    IVBUSD derivativeToken;

    address LendingAdapterAddress;
    address TokenAddress;
    address TreasuryAddress;

    uint256 _totalTokenReward; //  This tracks the total number of token rewards distributed on the cooperative savings

    uint256 _groupCreatorRewardPercent;

    uint256 _feePrecision = 10; //  This determines the lower limit of the fee to be charged. With precsion of 10, it means our fee can have a precision of 0.1% and above

    string constant PERCENTAGE_PAYOUT_TO_USERS = "PERCENTAGE_PAYOUT_TO_USERS";
    string constant PERCENTAGE_AS_PENALTY = "PERCENTAGE_AS_PENALTY";

    string constant XEND_FINANCE_COMMISION_DIVISOR =
        "XEND_FINANCE_COMMISION_DIVISOR";
    string constant XEND_FINANCE_COMMISION_DIVIDEND =
        "XEND_FINANCE_COMMISION_DIVIDEND";

    bool isDeprecated;

    modifier onlyNonDeprecatedCalls() {
        require(!isDeprecated, "Service contract has been deprecated");
        _;
    }
}



contract XendFinanceGroupHelpers is XendFinanceGroupContainer_Yearn_V1 {
    function _updateGroup(Group memory group) internal {
        uint256 index = _getGroupIndex(group.id);
        groupStorage.updateGroup(
            group.id,
            group.name,
            group.symbol,
            group.creatorAddress
        );
    }

    function _getGroupById(uint256 _groupId)
        internal
        view
        returns (Group memory)
    {
        (
            uint256 groupId,
            string memory name,
            string memory symbol,
            address payable creatorAddress
        ) = groupStorage.getGroupById(_groupId);

        Group memory group = Group(groupId, name, symbol, true, creatorAddress);
        return group;
    }

    function _getGroupByIndex(uint256 index)
        internal
        view
        returns (Group memory)
    {
        (
            uint256 groupId,
            string memory name,
            string memory symbol,
            address payable creatorAddress
        ) = groupStorage.getGroupByIndex(index);

        Group memory group = Group(groupId, name, symbol, true, creatorAddress);
        return group;
    }

    function _getGroupIndex(uint256 groupId) internal view returns (uint256) {
        return groupStorage.getGroupIndex(groupId);
    }

    function _createMemberIfNotExist(address payable depositor)
        internal
        returns (Member memory)
    {
        Member memory member = _getMember(depositor, false);
        return member;
    }

    function _createGroupMemberIfNotExist(
        address payable depositor,
        uint256 groupId
    ) internal returns (GroupMember memory) {
        GroupMember memory groupMember =
            _getGroupMember(depositor, groupId, false);
        return groupMember;
    }

    function _getMember(address payable depositor, bool throwOnNotFound)
        internal
        returns (Member memory)
    {
        bool memberExists = groupStorage.doesMemberExist(depositor);
        if (throwOnNotFound) require(memberExists, "Member not found");

        if (!memberExists) {
            groupStorage.createMember(depositor);
        }

        return Member(true, depositor);
    }

    function _getGroupMember(
        address payable depositor,
        uint256 groupId,
        bool throwOnNotFound
    ) internal returns (GroupMember memory) {
        bool groupMemberExists =
            groupStorage.doesGroupMemberExist(groupId, depositor);

        if (throwOnNotFound) require(groupMemberExists, "Member not found");

        if (!groupMemberExists) {
            groupStorage.createGroupMember(groupId, depositor);
        }

        return GroupMember(true, depositor, groupId);
    }

    function _getGroup(uint256 groupId) internal view returns (Group memory) {
        return _getGroupById(groupId);
    }

    modifier onlyGroupCreator(uint256 groupId) {
        Group memory group = _getGroup(groupId);

        require(
            msg.sender == group.creatorAddress,
            "unauthorized access to contract"
        );
        _;
    }
}

contract XendFinanceCycleHelpers is XendFinanceGroupHelpers {
    using SafeMath for uint256;

    using SafeERC20 for IERC20;

    function _updateCycleMember(CycleMember memory cycleMember) internal {
        cycleStorage.updateCycleMember(
            cycleMember.cycleId,
            cycleMember._address,
            cycleMember.totalLiquidityAsPenalty,
            cycleMember.numberOfCycleStakes,
            cycleMember.stakesClaimed,
            cycleMember.hasWithdrawn
        );
    }

    function _validateCycleCreationActionValid(
        uint256 groupId,
        uint256 maximumsSlots,
        bool hasMaximumSlots
    ) internal {
        bool doesGroupExist = groupStorage.doesGroupExist(groupId);

        require(doesGroupExist, "Group not found");

        if (hasMaximumSlots) {
            require(maximumsSlots > 0, "Maximum slot settings cannot be empty");
        }
    }

    function _getCycleGroup(uint256 cycleId)
        internal
        view
        returns (Group memory)
    {
        Cycle memory cycle = _getCycleById(cycleId);

        return _getGroupById(cycle.groupId);
    }

    function _getCycleById(uint256 cycleId)
        internal
        view
        returns (Cycle memory)
    {
        (
            uint256 id,
            uint256 groupId,
            uint256 numberOfDepositors,
            uint256 cycleStartTimeStamp,
            uint256 cycleDuration,
            uint256 maximumSlots,
            bool hasMaximumSlots,
            uint256 cycleStakeAmount,
            uint256 totalStakes,
            uint256 stakesClaimed,
            CycleStatus cycleStatus,
            uint256 stakesClaimedBeforeMaturity
        ) = cycleStorage.getCycleInfoById(cycleId);

        Cycle memory cycleInfo =
            Cycle(
                id,
                groupId,
                numberOfDepositors,
                cycleStartTimeStamp,
                cycleDuration,
                maximumSlots,
                cycleStakeAmount,
                totalStakes,
                stakesClaimed,
                hasMaximumSlots,
                true,
                cycleStatus,
                stakesClaimedBeforeMaturity
            );

        return cycleInfo;
    }

    function _getCycleByIndex(uint256 index)
        internal
        view
        returns (Cycle memory)
    {
        (
            uint256 id,
            uint256 groupId,
            uint256 numberOfDepositors,
            uint256 cycleStartTimeStamp,
            uint256 cycleDuration,
            uint256 maximumSlots,
            bool hasMaximumSlots,
            uint256 cycleStakeAmount,
            uint256 totalStakes,
            uint256 stakesClaimed,
            CycleStatus cycleStatus,
            uint256 stakesClaimedBeforeMaturity
        ) = cycleStorage.getCycleInfoByIndex(index);

        Cycle memory cycleInfo =
            Cycle(
                id,
                groupId,
                numberOfDepositors,
                cycleStartTimeStamp,
                cycleDuration,
                maximumSlots,
                cycleStakeAmount,
                totalStakes,
                stakesClaimed,
                hasMaximumSlots,
                true,
                cycleStatus,
                stakesClaimedBeforeMaturity
            );

        return cycleInfo;
    }

    function _getCycleFinancialByCycleId(uint256 cycleId)
        internal
        view
        returns (CycleFinancial memory)
    {
        (
            uint256 underlyingTotalDeposits,
            uint256 underlyingTotalWithdrawn,
            uint256 underlyingBalance,
            uint256 derivativeBalance,
            uint256 underylingBalanceClaimedBeforeMaturity,
            uint256 derivativeBalanceClaimedBeforeMaturity
        ) = cycleStorage.getCycleFinancialsByCycleId(cycleId);

        return
            CycleFinancial(
                true,
                cycleId,
                underlyingTotalDeposits,
                underlyingTotalWithdrawn,
                underlyingBalance,
                derivativeBalance,
                underylingBalanceClaimedBeforeMaturity,
                derivativeBalanceClaimedBeforeMaturity
            );
    }

    function _getCycleFinancialByIndex(uint256 index)
        internal
        view
        returns (CycleFinancial memory)
    {
        (
            uint256 cycleId,
            uint256 underlyingTotalDeposits,
            uint256 underlyingTotalWithdrawn,
            uint256 underlyingBalance,
            uint256 derivativeBalance,
            uint256 underylingBalanceClaimedBeforeMaturity,
            uint256 derivativeBalanceClaimedBeforeMaturity
        ) = cycleStorage.getCycleFinancialsByIndex(index);

        return
            CycleFinancial(
                true,
                cycleId,
                underlyingTotalDeposits,
                underlyingTotalWithdrawn,
                underlyingBalance,
                derivativeBalance,
                underylingBalanceClaimedBeforeMaturity,
                derivativeBalanceClaimedBeforeMaturity
            );
    }

    function _getCycleIndex(uint256 cycleId) internal view returns (uint256) {
        return cycleStorage.getCycleIndex(cycleId);
    }

    function _getCycleMemberIndex(
        uint256 cycleId,
        address payable memberAddress
    ) internal view returns (uint256) {
        return cycleStorage.getCycleMemberIndex(cycleId, memberAddress);
    }

    function _getCycleMember(address payable depositor, uint256 _cycleId)
        internal
        returns (CycleMember memory)
    {
        bool cycleMemberExists =
            cycleStorage.doesCycleMemberExist(_cycleId, depositor);

        require(cycleMemberExists, "Cycle Member not found");

        uint256 index = _getCycleMemberIndex(_cycleId, depositor);

        CycleMember memory cycleMember = _getCycleMember(index);
        return cycleMember;
    }

    function _CreateCycleMember(CycleMember memory cycleMember) internal {
        cycleStorage.createCycleMember(
            cycleMember.cycleId,
            cycleMember.groupId,
            cycleMember.totalLiquidityAsPenalty,
            cycleMember.numberOfCycleStakes,
            cycleMember.stakesClaimed,
            cycleMember._address,
            cycleMember.hasWithdrawn
        );
    }

    function _getCycleMember(uint256 index)
        internal
        view
        returns (CycleMember memory)
    {
        (
            uint256 cycleId,
            uint256 groupId,
            address payable _address,
            uint256 totalLiquidityAsPenalty,
            uint256 numberOfCycleStakes,
            uint256 stakesClaimed,
            bool hasWithdrawn
        ) = cycleStorage.getCycleMember(index);

        return
            CycleMember(
                cycleId,
                groupId,
                totalLiquidityAsPenalty,
                numberOfCycleStakes,
                stakesClaimed,
                true,
                _address,
                hasWithdrawn
            );
    }

    function _startCycle(Cycle memory cycle) internal {
        cycle.cycleStatus = CycleStatus.ONGOING;
        _updateCycle(cycle);
    }

    function _endCycle(Cycle memory cycle) internal {
        cycle.cycleStatus = CycleStatus.ENDED;
        _updateCycle(cycle);
    }

    function _updateCycle(Cycle memory cycle) internal {
        cycleStorage.updateCycle(
          cycle.id,
            cycle.numberOfDepositors,
            cycle.cycleStartTimeStamp,
            cycle.cycleDuration,
            cycle.maximumSlots,
            cycle.hasMaximumSlots,
            cycle.cycleStakeAmount,
            cycle.totalStakes,
            cycle.stakesClaimed,
            cycle.cycleStatus,
            cycle.stakesClaimedBeforeMaturity
        );
    }

    function _updateCycleFinancials(CycleFinancial memory cycleFinancial)
        internal
    {
        cycleStorage.updateCycleFinancials(
            cycleFinancial.cycleId,
            cycleFinancial.underlyingTotalDeposits,
            cycleFinancial.underlyingTotalWithdrawn,
            cycleFinancial.underlyingBalance,
            cycleFinancial.derivativeBalance,
            cycleFinancial.underylingBalanceClaimedBeforeMaturity,
            cycleFinancial.derivativeBalanceClaimedBeforeMaturity
        );
    }


    function _lendCycleDeposit(
        uint256 allowance,
        uint256 amountToDeductFromClient
    ) internal returns (uint256) {
        require(
            allowance >= amountToDeductFromClient,
            "Approve an amount to cover for stake purchase [1]"
        );

       
            _busd.safeTransferFrom(
                msg.sender,
                address(this),
                amountToDeductFromClient
            );
            // it doesnt get here
            // require(allowance < amountToDeductFromClient, "purposely doing this.. allowance is less than the amount");

     LendingAdapterAddress = lendingService.GetVenusLendingAdapterAddress();

        _busd.approve(LendingAdapterAddress, amountToDeductFromClient);

        uint256 balanceBeforeDeposit = lendingService.UserShares(address(this));

        lendingService.Save(amountToDeductFromClient);

        uint256 balanceAfterDeposit = lendingService.UserShares(address(this));

        return balanceAfterDeposit.sub(balanceBeforeDeposit);
    }

    function _joinCycle(
        uint256 cycleId,
        uint256 numberOfStakes,
        uint256 allowance,
        address payable depositorAddress
    ) internal {
        require(numberOfStakes > 0, "Minimum stakes that can be acquired is 1");

        Group memory group = _getCycleGroup(cycleId);
        Cycle memory cycle = _getCycleById(cycleId);
        CycleFinancial memory cycleFinancial =
            _getCycleFinancialByCycleId(cycleId);

        bool didCycleMemberExistBeforeNow =
            cycleStorage.doesCycleMemberExist(cycleId, depositorAddress);
        bool didGroupMemberExistBeforeNow =
            groupStorage.doesGroupMemberExist(group.id, depositorAddress);

        _validateCycleDepositCriteriaAreMet(
            cycle,
            didCycleMemberExistBeforeNow
        );

        uint256 amountToDeductFromClient =
            cycle.cycleStakeAmount.mul(numberOfStakes);
    // it gets here..
     //        require(allowance < amountToDeductFromClient, "purposely doing this.. allowance is less than the amount");

        CycleDepositResult memory result =
            _addDepositorToCycle(
                cycleId,
                cycle.cycleStakeAmount,
                numberOfStakes,
                amountToDeductFromClient,
                depositorAddress
            );

             // it doesnt get here.. 
     //        require(allowance < amountToDeductFromClient, "purposely doing this.. allowance is less than the amount");

        uint256 derivativeAmount =
            _lendCycleDeposit(allowance, amountToDeductFromClient);

        cycle = _updateCycleStakeDeposit(cycle, cycleFinancial, numberOfStakes);

        cycleFinancial.derivativeBalance = cycleFinancial.derivativeBalance.add(
            derivativeAmount
        );

        _updateCycleFinancials(cycleFinancial);

        emit UnderlyingAssetDeposited(
            cycle.id,
            depositorAddress,
            result.group.id,
            result.underlyingAmountDeposited,
            TokenAddress
        );

        if (!didCycleMemberExistBeforeNow) {
            cycle.numberOfDepositors = cycle.numberOfDepositors.add(1);

            emit MemberJoinedCycle(cycleId, depositorAddress, result.group.id);
        }

        if (!didGroupMemberExistBeforeNow) {
            emit MemberJoinedGroup(depositorAddress, result.group.id);
        }

        _updateCycle(cycle);
    }

    function _updateCycleStakeDeposit(
        Cycle memory cycle,
        CycleFinancial memory cycleFinancial,
        uint256 numberOfCycleStakes
    ) internal returns (Cycle memory) {
        cycle.totalStakes = cycle.totalStakes.add(numberOfCycleStakes);

        uint256 depositAmount = cycle.cycleStakeAmount.mul(numberOfCycleStakes);
        cycleFinancial.underlyingTotalDeposits = cycleFinancial
            .underlyingTotalDeposits
            .add(depositAmount);
        _updateCycleFinancials(cycleFinancial);
        _updateTotalTokenDepositAmount(depositAmount);
        return cycle;
    }

    function _updateTotalTokenDepositAmount(uint256 amount) internal {
        groupStorage.incrementTokenDeposit(TokenAddress, amount);
    }

    function _validateCycleDepositCriteriaAreMet(
        Cycle memory cycle,
        bool didCycleMemberExistBeforeNow
    ) internal view {
        bool hasMaximumSlots = cycle.hasMaximumSlots;
        if (hasMaximumSlots && !didCycleMemberExistBeforeNow) {
            require(
                cycle.numberOfDepositors < cycle.maximumSlots,
                "Maximum slot for depositors has been reached"
            );
        }

        require(
            cycle.cycleStatus == CycleStatus.NOT_STARTED,
            "This cycle is not accepting deposits anymore"
        );
    }

    function _addDepositorToCycle(
        uint256 cycleId,
        uint256 cycleAmountForStake,
        uint256 numberOfStakes,
        uint256 amountToDeductFromClient,
        address payable depositorAddress
    ) internal returns (CycleDepositResult memory) {
        
        Group memory group = _getCycleGroup(cycleId);

       // require(cycleAmountForStake > amountToDeductFromClient, "purposely doing this.. cycle amount must be greater than amount to deduct from client");

        Member memory member = _createMemberIfNotExist(depositorAddress);
        GroupMember memory groupMember =
            _createGroupMemberIfNotExist(depositorAddress, group.id);

        bool doesCycleMemberExist =
            cycleStorage.doesCycleMemberExist(cycleId, depositorAddress);

            

        CycleMember memory cycleMember =
            CycleMember(
                cycleId,
                group.id,
                0,
                0,
                0,
                true,
                depositorAddress,
                false
            );

        if (doesCycleMemberExist) {
            cycleMember = _getCycleMember(depositorAddress, cycleId);
        }

        uint256 underlyingAmount = amountToDeductFromClient;
       
        cycleMember = _saveMemberDeposit(
            doesCycleMemberExist,
            cycleMember,
            numberOfStakes
        );

       
        CycleDepositResult memory result =
            CycleDepositResult(
                group,
                member,
                groupMember,
                cycleMember,
                underlyingAmount
            );

        return result;
    }

    function _saveMemberDeposit(
        bool didCycleMemberExistBeforeNow,
        CycleMember memory cycleMember,
        uint256 numberOfCycleStakes
    ) internal returns (CycleMember memory) {
        
        cycleMember.numberOfCycleStakes = cycleMember.numberOfCycleStakes.add(
            numberOfCycleStakes
        );
        
       
 

        if (didCycleMemberExistBeforeNow == true) {
            
            _updateCycleMember(cycleMember);
            
        }
        else 
        {
            _CreateCycleMember(cycleMember);
        }
 
        return cycleMember;
    }


    function _endCycle(uint256 cycleId)
        internal
        returns (Cycle memory, CycleFinancial memory)
    {
        bool isCycleReadyToBeEnded = _isCycleReadyToBeEnded(cycleId);
        require(isCycleReadyToBeEnded, "Cycle is still ongoing");

        Cycle memory cycle = _getCycleById(cycleId);
        CycleFinancial memory cycleFinancial =
            _getCycleFinancialByCycleId(cycleId);

        uint256 derivativeBalanceToWithdraw =
            cycleFinancial.derivativeBalance.sub(
                cycleFinancial.derivativeBalanceClaimedBeforeMaturity
            );

            LendingAdapterAddress = lendingService.GetVenusLendingAdapterAddress();

        derivativeToken.approve(
            LendingAdapterAddress,
            derivativeBalanceToWithdraw
        );

        uint256 underlyingAmount = _redeemLending(derivativeBalanceToWithdraw);

        cycleFinancial.underlyingBalance = cycleFinancial.underlyingBalance.add(
            underlyingAmount
        );

        cycle.cycleStatus = CycleStatus.ENDED;

        return (cycle, cycleFinancial);
    }

    function _isCycleReadyToBeEnded(uint256 cycleId)
        internal
        view
        returns (bool)
    {
        Cycle memory cycle = _getCycleById(cycleId);

        if (cycle.cycleStatus != CycleStatus.ONGOING) return false;

        uint256 currentTimeStamp = now;
        uint256 cycleEndTimeStamp =
            cycle.cycleStartTimeStamp + cycle.cycleDuration;

        return currentTimeStamp >= cycleEndTimeStamp;
    }

    function _redeemLending(uint256 derivativeBalance)
        internal
        returns (uint256)
    {
        uint256 balanceBeforeWithdraw =
            lendingService.UserDAIBalance(address(this));

        lendingService.WithdrawBySharesOnly(derivativeBalance);

        uint256 balanceAfterWithdraw =
            lendingService.UserDAIBalance(address(this));

        uint256 amountOfUnderlyingAssetWithdrawn =
            balanceAfterWithdraw.sub(balanceBeforeWithdraw);

        return amountOfUnderlyingAssetWithdrawn;
    }

    modifier onlyCycleCreatorOrMember(uint256 cycleId) {
        Group memory group = _getCycleGroup(cycleId);

        bool isCreatorOrMember = msg.sender == group.creatorAddress;

        if (!isCreatorOrMember) {
            uint256 index = _getCycleMemberIndex(cycleId, msg.sender);
            CycleMember memory cycleMember = _getCycleMember(index);

            isCreatorOrMember = cycleMember._address == msg.sender;
        }

        require(isCreatorOrMember, "unauthorized access to contract");
        _;
    }
}

contract XendFinanceGroup_Yearn_V1 is
    XendFinanceCycleHelpers,
    ISavingsConfigSchema,
    Ownable,
    ReentrancyGuard
{
    using SafeMath for uint256;

    using SafeERC20 for IERC20;

    using SafeERC20 for IVBUSD;

    using Address for address payable;

    constructor(
        address lendingServiceAddress,
        address tokenAddress,
        address groupStorageAddress,
        address cycleStorageAddress,
        address treasuryAddress,
        address savingsConfigAddress,
        address rewardConfigAddress,
        address xendTokenAddress,
        address derivativeTokenAddress
    ) public {
        lendingService = IVenusLendingService(lendingServiceAddress);
        _busd = IERC20(tokenAddress);
        groupStorage = IGroups(groupStorageAddress);
        cycleStorage = ICycles(cycleStorageAddress);
        treasury = ITreasury(treasuryAddress);
        savingsConfig = ISavingsConfig(savingsConfigAddress);
        rewardConfig = IRewardConfig(rewardConfigAddress);
        xendToken = IXendToken(xendTokenAddress);
        derivativeToken = IVBUSD(derivativeTokenAddress);
        TokenAddress = tokenAddress;
        TreasuryAddress = treasuryAddress;
    }

    function setGroupCreatorRewardPercent(uint256 percent) external onlyOwner {
        _groupCreatorRewardPercent = percent;
    }

    function UpdateFeePrecision(uint256 feePrecision) external onlyOwner {
        _feePrecision = feePrecision;
    }

    function setAdapterAddress() external onlyOwner {
        LendingAdapterAddress = lendingService.GetVenusLendingAdapterAddress();
    }

    function GetTotalTokenRewardDistributed() external view returns (uint256) {
        return _totalTokenReward;
    }

    function withdrawFromCycleWhileItIsOngoing(uint256 cycleId)
        external
        onlyNonDeprecatedCalls
    {
        address payable memberAddress = msg.sender;
        _withdrawFromCycleWhileItIsOngoing(cycleId, memberAddress);
    }

    function _withdrawFromCycleWhileItIsOngoing(
        uint256 cycleId,
        address payable memberAddress
    ) internal nonReentrant {
        bool isCycleReadyToBeEnded = _isCycleReadyToBeEnded(cycleId);

        require(
            !isCycleReadyToBeEnded,
            "Cycle has already ended, use normal withdrawl route"
        );

        Cycle memory cycle = _getCycleById(cycleId);
        CycleFinancial memory cycleFinancial =
            _getCycleFinancialByCycleId(cycleId);

        require(
            cycleStorage.doesCycleMemberExist(cycleId, memberAddress),
            "You are not a member of this cycle"
        );

        CycleMember memory cycleMember =
            _getCycleMemberInfo(cycleId, memberAddress);

        uint256 numberOfStakesByMember = cycleMember.numberOfCycleStakes;
        //uint256 pricePerFullShare = lendingService.getPricePerFullShare();

        // get's the worth of one stake of the cycle in the derivative amount e.g yDAI
        uint256 derivativeAmountForStake =
            cycleFinancial.derivativeBalance.div(cycle.totalStakes);

        //get's how much of a crypto asset the user has deposited. e.g yDAI
        uint256 derivativeBalanceForMember =
            derivativeAmountForStake.mul(numberOfStakesByMember);

            LendingAdapterAddress = lendingService.GetVenusLendingAdapterAddress();

        derivativeToken.approve(
            LendingAdapterAddress,
            derivativeBalanceForMember
        );

        //get's the crypto equivalent of a members derivative balance. Crytpo here refers to DAI. this is gotten after the user's ydai balance has been converted to dai
        uint256 underlyingAmountThatMemberDepositIsWorth =
            _redeemLending(derivativeBalanceForMember);

        uint256 initialUnderlyingDepositByMember =
            numberOfStakesByMember.mul(cycle.cycleStakeAmount);

        //deduct charges for early withdrawal
        uint256 amountToChargeAsPenalites =
            _computeAmountToChargeAsPenalites(
                underlyingAmountThatMemberDepositIsWorth
            );

        //deduct xend finance fees
        uint256 amountToChargeAsFees =
            _computeXendFinanceCommisions(
                underlyingAmountThatMemberDepositIsWorth
            );

        uint256 totalDeductible =
            amountToChargeAsPenalites.add(amountToChargeAsFees);

        underlyingAmountThatMemberDepositIsWorth.sub(totalDeductible);

        WithdrawalResolution memory withdrawalResolution =
            _computeAmountToSendToParties(
                initialUnderlyingDepositByMember,
                underlyingAmountThatMemberDepositIsWorth
            );

        // withdrawalResolution.amountToSendToTreasury = withdrawalResolution
        //     .amountToSendToTreasury
        //     .add(totalDeductible);

        if (withdrawalResolution.amountToSendToTreasury > 0) {
            _busd.approve(
                TreasuryAddress,
                withdrawalResolution.amountToSendToTreasury
            );
            treasury.depositToken(TokenAddress);
        }
        

        require(
            withdrawalResolution.amountToSendToMember > 0,
            "After deducting early withdrawal penalties and fees, there's nothing left for you"
        );
        _busd.safeTransfer(
            cycleMember._address,
            withdrawalResolution.amountToSendToMember
        );

        uint256 totalUnderlyingAmountSentOut =
            withdrawalResolution.amountToSendToTreasury.add(
                withdrawalResolution.amountToSendToMember
            );

        cycle.stakesClaimedBeforeMaturity = cycle
            .stakesClaimedBeforeMaturity
            .add(numberOfStakesByMember);
        cycleFinancial.underylingBalanceClaimedBeforeMaturity = cycleFinancial
            .underylingBalanceClaimedBeforeMaturity
            .add(totalUnderlyingAmountSentOut);
        cycleFinancial.derivativeBalanceClaimedBeforeMaturity = cycleFinancial
            .derivativeBalanceClaimedBeforeMaturity
            .add(derivativeBalanceForMember);

        cycleMember.hasWithdrawn = true;
        cycleMember.stakesClaimed = cycleMember.stakesClaimed.add(
            numberOfStakesByMember
        );

        _updateCycle(cycle);
        _updateCycleMember(cycleMember);
        _updateCycleFinancials(cycleFinancial);
    }

    function getDerivativeAmountForUserStake(
        uint256 cycleId,
        address payable memberAddress
    ) external view returns (uint256) {
        Cycle memory cycle = _getCycleById(cycleId);
        CycleFinancial memory cycleFinancial =
            _getCycleFinancialByCycleId(cycleId);
        bool memberExistInCycle =
            cycleStorage.doesCycleMemberExist(cycleId, memberAddress);

        require(memberExistInCycle, "You are not a member of this cycle");

        uint256 index = _getCycleMemberIndex(cycle.id, memberAddress);

        CycleMember memory cycleMember = _getCycleMember(index);

        uint256 numberOfStakesByMember = cycleMember.numberOfCycleStakes;

        // get's the worth of one stake of the cycle in the derivative amount e.g yDAI
        uint256 derivativeAmountForStake =
            cycleFinancial.derivativeBalance.div(cycle.totalStakes);

        //get's how much of a crypto asset the user has deposited. e.g yDAI
        uint256 derivativeBalanceForMember =
            derivativeAmountForStake.mul(numberOfStakesByMember);
        return derivativeBalanceForMember;
    }

    function withdrawFromCycle(uint256 cycleId)
        external
        onlyNonDeprecatedCalls
    {
        address payable memberAddress = msg.sender;
        uint256 amountToSendToMember =
            _withdrawFromCycle(cycleId, memberAddress);
        emit DerivativeAssetWithdrawn(
            cycleId,
            memberAddress,
            amountToSendToMember,
            TokenAddress
        );
    }

    function withdrawFromCycle(uint256 cycleId, address payable memberAddress)
        external
        onlyNonDeprecatedCalls
    {
        uint256 amountToSendToMember =
            _withdrawFromCycle(cycleId, memberAddress);

        emit DerivativeAssetWithdrawn(
            cycleId,
            memberAddress,
            amountToSendToMember,
            TokenAddress
        );
    }

    function _getCycleMemberInfo(uint256 cycleId, address payable memberAddress)
        internal
        returns (CycleMember memory)
    {
        require(
            cycleStorage.doesCycleMemberExist(cycleId, memberAddress),
            "You are not a member of this cycle"
        );

        uint256 index = _getCycleMemberIndex(cycleId, memberAddress);
        CycleMember memory cycleMember = _getCycleMember(index);

        require(!cycleMember.hasWithdrawn, "Funds have already been withdrawn");

        return cycleMember;
    }

    function _withdrawFromCycle(uint256 cycleId, address payable memberAddress)
        internal
        nonReentrant
        returns (uint256 amountToSendToMember)
    {
        Cycle memory cycle;
        CycleFinancial memory cycleFinancial;

        (cycle, cycleFinancial) = _endCycle(cycleId);

        CycleMember memory cycleMember =
            _getCycleMemberInfo(cycleId, memberAddress);

        //how many stakes a cycle member has
        uint256 stakesHoldings = cycleMember.numberOfCycleStakes;

        //getting the underlying asset amount that backs 1 stake amount
        uint256 totalStakesLeftWhenTheCycleEnded =
            cycle.totalStakes.sub(cycle.stakesClaimedBeforeMaturity);
        uint256 underlyingAssetForStake =
            cycleFinancial.underlyingBalance.div(
                totalStakesLeftWhenTheCycleEnded
            );

            

        //cycle members stake amount current worth

        uint256 underlyingAmountThatMemberDepositIsWorth =
            underlyingAssetForStake.mul(stakesHoldings);

        uint256 initialUnderlyingDepositByMember =
            stakesHoldings.mul(cycle.cycleStakeAmount);

        //deduct xend finance fees
        uint256 amountToChargeAsFees =
            _computeXendFinanceCommisions(
                underlyingAmountThatMemberDepositIsWorth
            );

        uint256 creatorReward =
            amountToChargeAsFees.mul(_groupCreatorRewardPercent).div(
                _feePrecision.mul(100)
            );

        uint256 finalAmountToChargeAsFees =
            amountToChargeAsFees.sub(creatorReward);

        underlyingAmountThatMemberDepositIsWorth = underlyingAmountThatMemberDepositIsWorth
            .sub(finalAmountToChargeAsFees.add(creatorReward));

        WithdrawalResolution memory withdrawalResolution =
            _computeAmountToSendToParties(
                initialUnderlyingDepositByMember,
                underlyingAmountThatMemberDepositIsWorth
            );

        withdrawalResolution.amountToSendToTreasury = withdrawalResolution
            .amountToSendToTreasury
            .add(finalAmountToChargeAsFees);

        if (withdrawalResolution.amountToSendToTreasury > 0) {
            _busd.approve(
                TreasuryAddress,
                withdrawalResolution.amountToSendToTreasury
            );
            treasury.depositToken(TokenAddress);
            _busd.safeTransfer(_getGroupCreator(cycle.groupId), creatorReward);
        }

        if (withdrawalResolution.amountToSendToMember > 0) {
            _busd.safeTransfer(
                cycleMember._address,
                withdrawalResolution.amountToSendToMember
            );
        }

        uint256 totalUnderlyingAmountSentOut =
            withdrawalResolution.amountToSendToTreasury.add(
                withdrawalResolution.amountToSendToMember
            );

        cycle.stakesClaimed = cycle.stakesClaimed.add(stakesHoldings);
        cycleFinancial.underlyingTotalWithdrawn = cycleFinancial
            .underlyingTotalWithdrawn
            .add(totalUnderlyingAmountSentOut);

        cycleMember.hasWithdrawn = true;
        cycleMember.stakesClaimed = cycleMember.stakesClaimed.add(
            stakesHoldings
        );
        uint256 amountDeposited = cycle.cycleStakeAmount.mul(stakesHoldings);
        _rewardUserWithTokens(
            cycle.cycleDuration,
            amountDeposited,
            cycleMember._address
        );

        _updateCycle(cycle);
        _updateCycleFinancials(cycleFinancial);
        _updateCycleMember(cycleMember);

        return withdrawalResolution.amountToSendToMember;
    }

    function _getGroupCreator(uint256 groupId) internal returns (address) {
        Group memory group = _getGroup(groupId);

        address groupCreator = group.creatorAddress;

        return groupCreator;
    }

    function deprecateContract(address newServiceAddress)
        external
        onlyOwner
        onlyNonDeprecatedCalls
    {
        isDeprecated = true;
        groupStorage.reAssignStorageOracle(newServiceAddress);
        cycleStorage.reAssignStorageOracle(newServiceAddress);
        uint256 derivativeTokenBalance =
            derivativeToken.balanceOf(address(this));
        derivativeToken.safeTransfer(newServiceAddress, derivativeTokenBalance);
    }

    function _rewardUserWithTokens(
        uint256 totalCycleTimeInSeconds,
        uint256 amountDeposited,
        address payable cycleMemberAddress
    ) internal {
        uint256 numberOfRewardTokens =
            rewardConfig.CalculateCooperativeSavingsReward(
                totalCycleTimeInSeconds,
                amountDeposited
            );

        if (numberOfRewardTokens > 0) {
            xendToken.mint(cycleMemberAddress, numberOfRewardTokens);
            groupStorage.setXendTokensReward(
                cycleMemberAddress,
                numberOfRewardTokens
            );

            //  increase the total number of xend token rewards distributed
            _totalTokenReward = _totalTokenReward.add(numberOfRewardTokens);

            emit XendTokenReward(now, cycleMemberAddress, numberOfRewardTokens);
        }
    }

    function _computeAmountToChargeAsPenalites(uint256 worthOfMemberDepositNow)
        internal
        returns (uint256)
    {
        (
            uint256 minimum,
            uint256 maximum,
            uint256 exact,
            bool applies,
            RuleDefinition ruleDefinition
        ) = savingsConfig.getRuleSet(PERCENTAGE_AS_PENALTY);

        require(applies, "unsupported rule defintion for rule set");

        require(
            ruleDefinition == RuleDefinition.VALUE,
            "unsupported rule defintion for penalty percentage rule set"
        );

        require(
            worthOfMemberDepositNow > 0,
            "member deposit really isn't worth much"
        );

        uint256 amountToChargeAsPenalites =
            worthOfMemberDepositNow.mul(exact).div(100);
        return amountToChargeAsPenalites;
    }

    function _computeXendFinanceCommisions(uint256 worthOfMemberDepositNow)
        internal
        returns (uint256)
    {
        uint256 dividend = _getDividend();
        uint256 divisor = _getDivisor();

        require(
            worthOfMemberDepositNow > 0,
            "member deposit really isn't worth much"
        );

        return worthOfMemberDepositNow.mul(dividend).div(divisor).div(100);
    }

    function _getDivisor() internal returns (uint256) {
        (
            uint256 minimumDivisor,
            uint256 maximumDivisor,
            uint256 exactDivisor,
            bool appliesDivisor,
            RuleDefinition ruleDefinitionDivisor
        ) = savingsConfig.getRuleSet(XEND_FINANCE_COMMISION_DIVISOR);

        require(appliesDivisor, "unsupported rule defintion for rule set");

        require(
            ruleDefinitionDivisor == RuleDefinition.VALUE,
            "unsupported rule defintion for penalty percentage rule set"
        );
        return exactDivisor;
    }

    function _getDividend() internal returns (uint256) {
        (
            uint256 minimumDividend,
            uint256 maximumDividend,
            uint256 exactDividend,
            bool appliesDividend,
            RuleDefinition ruleDefinitionDividend
        ) = savingsConfig.getRuleSet(XEND_FINANCE_COMMISION_DIVIDEND);

        require(appliesDividend, "unsupported rule defintion for rule set");

        require(
            ruleDefinitionDividend == RuleDefinition.VALUE,
            "unsupported rule defintion for penalty percentage rule set"
        );
        return exactDividend;
    }

    //Determines how much we send to the treasury and how much we send to the member
    function _computeAmountToSendToParties(
        uint256 totalUnderlyingAmountMemberDeposited,
        uint256 worthOfMemberDepositNow
    ) internal returns (WithdrawalResolution memory) {
        (
            uint256 minimum,
            uint256 maximum,
            uint256 exact,
            bool applies,
            RuleDefinition ruleDefinition
        ) = savingsConfig.getRuleSet(PERCENTAGE_PAYOUT_TO_USERS);

        require(applies, "unsupported rule defintion for rule set");

        require(
            ruleDefinition == RuleDefinition.VALUE,
            "unsupported rule defintion for payout  percentage rule set"
        );

        //ensures we send what the user's investment is currently worth when his original deposit did not appreciate in value
        if (totalUnderlyingAmountMemberDeposited >= worthOfMemberDepositNow) {
            return WithdrawalResolution(worthOfMemberDepositNow, 0);
        } else {
            uint256 maxAmountUserCanBePaid =
                _getMaxAmountUserCanBePaidConsideringInterestLimit(
                    exact,
                    totalUnderlyingAmountMemberDeposited
                );

            if (worthOfMemberDepositNow > maxAmountUserCanBePaid) {
                uint256 amountToSendToTreasury =
                    worthOfMemberDepositNow.sub(maxAmountUserCanBePaid);
                return
                    WithdrawalResolution(
                        maxAmountUserCanBePaid,
                        amountToSendToTreasury
                    );
            } else {
                return WithdrawalResolution(worthOfMemberDepositNow, 0);
            }
        }
    }

    function _getMaxAmountUserCanBePaidConsideringInterestLimit(
        uint256 maxPayoutPercentage,
        uint256 totalUnderlyingAmountMemberDeposited
    ) internal returns (uint256) {
        uint256 percentageConsideration = 100 + maxPayoutPercentage;
        return
            totalUnderlyingAmountMemberDeposited
                .mul(percentageConsideration)
                .div(100);
    }

    function getRecordIndexLengthForCycleMembers(uint256 cycleId)
        external
        view
        onlyNonDeprecatedCalls
        returns (uint256)
    {
        return cycleStorage.getRecordIndexLengthForCycleMembers(cycleId);
    }

    function getRecordIndexLengthForCycleMembersByDepositor(
        address depositorAddress
    ) external view onlyNonDeprecatedCalls returns (uint256) {
        return
            cycleStorage.getRecordIndexLengthForCycleMembersByDepositor(
                depositorAddress
            );
    }

    function getRecordIndexLengthForGroupMembers(uint256 groupId)
        external
        view
        onlyNonDeprecatedCalls
        returns (uint256)
    {
        return groupStorage.getRecordIndexLengthForGroupMembersIndexer(groupId);
    }

    function getRecordIndexLengthForGroupMembersByDepositor(
        address depositorAddress
    ) external view onlyNonDeprecatedCalls returns (uint256) {
        return
            groupStorage.getRecordIndexLengthForGroupMembersIndexerByDepositor(
                depositorAddress
            );
    }

    function getRecordIndexLengthForGroupCycles(uint256 groupId)
        external
        view
        onlyNonDeprecatedCalls
        returns (uint256)
    {
        return cycleStorage.getRecordIndexLengthForGroupCycleIndexer(groupId);
    }

    function getRecordIndexLengthForCreator(address groupCreator)
        external
        view
        onlyNonDeprecatedCalls
        returns (uint256)
    {
        return groupStorage.getRecordIndexLengthForCreator(groupCreator);
    }

    function getSecondsLeftForCycleToEnd(uint256 cycleId)
        external
        view
        onlyNonDeprecatedCalls
        returns (uint256)
    {
        Cycle memory cycle = _getCycleById(cycleId);
        require(cycle.cycleStatus == CycleStatus.ONGOING);
        uint256 cycleEndTimeStamp =
            cycle.cycleStartTimeStamp.add(cycle.cycleDuration);

        if (cycleEndTimeStamp >= now) return cycleEndTimeStamp.sub(now);
        else return 0;
    }

    function getSecondsLeftForCycleToStart(uint256 cycleId)
        external
        view
        onlyNonDeprecatedCalls
        returns (uint256)
    {
        Cycle memory cycle = _getCycleById(cycleId);
        require(cycle.cycleStatus == CycleStatus.NOT_STARTED);

        if (cycle.cycleStartTimeStamp >= now)
            return cycle.cycleStartTimeStamp.sub(now);
        else return 0;
    }

    function getCycleFinancials(uint256 index)
        external
        view
        onlyNonDeprecatedCalls
        returns (
            uint256 underlyingTotalDeposits,
            uint256 underlyingTotalWithdrawn,
            uint256 underlyingBalance,
            uint256 derivativeBalance,
            uint256 underylingBalanceClaimedBeforeMaturity,
            uint256 derivativeBalanceClaimedBeforeMaturity
        )
    {
        CycleFinancial memory cycleFinancial = _getCycleFinancialByIndex(index);

        return (
            cycleFinancial.underlyingTotalDeposits,
            cycleFinancial.underlyingTotalWithdrawn,
            cycleFinancial.underlyingBalance,
            cycleFinancial.derivativeBalance,
            cycleFinancial.underylingBalanceClaimedBeforeMaturity,
            cycleFinancial.derivativeBalanceClaimedBeforeMaturity
        );
    }

    function getCycleByIndex(uint256 index)
        external
        view
        onlyNonDeprecatedCalls
        returns (
            uint256 id,
            uint256 groupId,
            uint256 numberOfDepositors,
            uint256 cycleStartTimeStamp,
            uint256 cycleDuration,
            uint256 maximumSlots,
            bool hasMaximumSlots,
            uint256 cycleStakeAmount,
            uint256 totalStakes,
            uint256 stakesClaimed,
            CycleStatus cycleStatus,
            uint256 stakesClaimedBeforeMaturity
        )
    {
        Cycle memory cycle = _getCycleByIndex(index);

        return (
            cycle.id,
            cycle.groupId,
            cycle.numberOfDepositors,
            cycle.cycleStartTimeStamp,
            cycle.cycleDuration,
            cycle.maximumSlots,
            cycle.hasMaximumSlots,
            cycle.cycleStakeAmount,
            cycle.totalStakes,
            cycle.stakesClaimed,
            cycle.cycleStatus,
            cycle.stakesClaimedBeforeMaturity
        );
    }

    function getCycleMember(uint256 index)
        external
        view
        onlyNonDeprecatedCalls
        returns (
            uint256 cycleId,
            uint256 groupId,
            uint256 totalLiquidityAsPenalty,
            uint256 numberOfCycleStakes,
            uint256 stakesClaimed,
            bool exist,
            address payable _address,
            bool hasWithdrawn
        )
    {
        CycleMember memory cycleMember = _getCycleMember(index);
        return (
            cycleMember.cycleId,
            cycleMember.groupId,
            cycleMember.totalLiquidityAsPenalty,
            cycleMember.numberOfCycleStakes,
            cycleMember.stakesClaimed,
            cycleMember.exist,
            cycleMember._address,
            cycleMember.hasWithdrawn
        );
    }

    function activateCycle(uint256 cycleId)
        external
        onlyNonDeprecatedCalls
        onlyCycleCreatorOrMember(cycleId)
    {
        Cycle memory cycle = _getCycleById(cycleId);
        CycleFinancial memory cycleFinancial =
            _getCycleFinancialByCycleId(cycleId);

        uint256 currentTimeStamp = now;
        require(
            cycle.cycleStatus == CycleStatus.NOT_STARTED,
            "Cannot activate a cycle not in the 'NOT_STARTED' state"
        );
        require(
            cycle.numberOfDepositors > 0,
            "Cannot activate cycle that has no depositors"
        );

        require(
            cycle.cycleStartTimeStamp <= currentTimeStamp,
            "Cycle start time has not been reached"
        );

        cycle.cycleStartTimeStamp = currentTimeStamp;
        _startCycle(cycle);
        

        emit CycleStartedEvent(
            cycleId,
            currentTimeStamp,
            block.number,
            cycleFinancial.underlyingTotalDeposits
        );
    }

    function endCycle(uint256 cycleId) external onlyNonDeprecatedCalls {
        _endCycle(cycleId);
    }


    function createGroup(string calldata name, string calldata symbol)
        external
        onlyNonDeprecatedCalls
    {
        _validateGroupNameAndSymbolIsAvailable(name, symbol);

        uint256 groupId = groupStorage.createGroup(name, symbol, msg.sender);

        emit GroupCreated(groupId, msg.sender);
    }

    function _validateGroupNameAndSymbolIsAvailable(
        string memory name,
        string memory symbol
    ) internal {
        bytes memory nameInBytes = bytes(name); // Uses memory
        bytes memory symbolInBytes = bytes(symbol); // Uses memory

        require(nameInBytes.length > 0, "Group name cannot be empty");
        require(symbolInBytes.length > 0, "Group sysmbol cannot be empty");

        require(
            !groupStorage.doesGroupExist(name),
            "Group name has already been used"
        );
    }

    function getGroupByIndex(uint256 index)
        external
        view
        onlyNonDeprecatedCalls
        returns (
            bool exists,
            uint256 id,
            string memory name,
            string memory symbol,
            address payable creatorAddress
        )
    {
        Group memory group = _getGroupByIndex(index);
        return (
            group.exists,
            group.id,
            group.name,
            group.symbol,
            group.creatorAddress
        );
    }

    function getGroupById(uint256 _id)
        external
        view
        onlyNonDeprecatedCalls
        returns (
            bool exists,
            uint256 id,
            string memory name,
            string memory symbol,
            address payable creatorAddress
        )
    {
        Group memory group = _getGroupById(_id);
        return (
            group.exists,
            group.id,
            group.name,
            group.symbol,
            group.creatorAddress
        );
    }

    //
    function createCycle(
        uint256 groupId,
        uint256 startTimeStamp,
        uint256 duration,
        uint256 maximumSlots,
        bool hasMaximumSlots,
        uint256 cycleStakeAmount
    ) external onlyNonDeprecatedCalls onlyGroupCreator(groupId) {
        _validateCycleCreationActionValid(
            groupId,
            maximumSlots,
            hasMaximumSlots
        );

        uint256 cycleId =
            cycleStorage.createCycle(
                groupId,
                0,
                startTimeStamp,
                duration,
                maximumSlots,
                hasMaximumSlots,
                cycleStakeAmount,
                0,
                0,
                CycleStatus.NOT_STARTED,
                0
            );

        cycleStorage.createCycleFinancials(cycleId, groupId, 0, 0, 0, 0, 0, 0);

        emit CycleCreated(
            cycleId,
            maximumSlots,
            hasMaximumSlots,
            cycleStakeAmount,
            startTimeStamp,
            duration
        );
    }

    function _getAllowanceForBusd() internal view returns (uint256) {
        address recipient = address(this);
        uint256 amountDepositedByUser = _busd.allowance(msg.sender, recipient);
        require(
            amountDepositedByUser > 0,
            "Approve an amount to cover for stake purchase [0]"
        );

        return amountDepositedByUser;
    }

    function joinCycle(uint256 cycleId, uint256 numberOfStakes)
        external
        onlyNonDeprecatedCalls
    {
        uint256 allowance = _getAllowanceForBusd();
        address payable depositorAddress = msg.sender;
        _joinCycle(cycleId, numberOfStakes, allowance, depositorAddress);
    }
}
