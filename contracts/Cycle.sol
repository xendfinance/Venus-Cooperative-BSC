pragma solidity 0.6.6;
pragma experimental ABIEncoderV2;

import "./IGroupSchema.sol";
import "./StorageOwners.sol";

contract Cycles is IGroupSchema, StorageOwners {
    // list of Group Cycles
    Cycle[] private Cycles;
    CycleFinancial[] private CycleFinancials;

    //Mapping that enables ease of traversal of the cycle records. Key is cycle id
    mapping(uint256 => RecordIndex) private CycleIndexer;

    //Mapping that enables ease of traversal of cycle records by the group. key is group id
    mapping(uint256 => RecordIndex[]) private GroupCycleIndexer;

    //Mapping that enables ease of traversal of the cycle financials records. Key is cycle id
    mapping(uint256 => RecordIndex) private CycleFinancialsIndexer;

    //Mapping that enables ease of traversal of cycle financials records by the group. key is group id
    mapping(uint256 => RecordIndex[]) private GroupCycleFinancialsIndexer;

    CycleMember[] private CycleMembers;

    //Mapping of a cycle members. key is the cycle id
    mapping(uint256 => RecordIndex[]) private CycleMembersIndexer;
    //Mapping of a cycle members, key is depositor address
    mapping(address => RecordIndex[]) private CycleMembersIndexerByDepositor;
    //Mapping that enables easy traversal of cycle members in a group. outer key is the cycle id, inner key is the member address
    mapping(uint256 => mapping(address => RecordIndex))
        private CycleMembersDeepIndexer;

    uint256 lastCycleId;

    function getCycleInfoByIndex(uint256 index)
        external
        view
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
        Cycle memory cycle = Cycles[index];

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

    function getCycleInfoById(uint256 cycleId)
        external
        view
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
        uint256 index = _getCycleIndex(cycleId);

        Cycle memory cycle = Cycles[index];

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

    function getCycleFinancialsByIndex(uint256 index)
        external
        view
        returns (
            uint256 cycleId,
            uint256 underlyingTotalDeposits,
            uint256 underlyingTotalWithdrawn,
            uint256 underlyingBalance,
            uint256 derivativeBalance,
            uint256 underylingBalanceClaimedBeforeMaturity,
            uint256 derivativeBalanceClaimedBeforeMaturity
        )
    {
        CycleFinancial memory cycleFinancial = CycleFinancials[index];

        return (
            cycleFinancial.cycleId,
            cycleFinancial.underlyingTotalDeposits,
            cycleFinancial.underlyingTotalWithdrawn,
            cycleFinancial.underlyingBalance,
            cycleFinancial.derivativeBalance,
            cycleFinancial.underylingBalanceClaimedBeforeMaturity,
            cycleFinancial.derivativeBalanceClaimedBeforeMaturity
        );
    }

    function getCycleFinancialsByCycleId(uint256 cycleId)
        external
        view
        returns (
            uint256 underlyingTotalDeposits,
            uint256 underlyingTotalWithdrawn,
            uint256 underlyingBalance,
            uint256 derivativeBalance,
            uint256 underylingBalanceClaimedBeforeMaturity,
            uint256 derivativeBalanceClaimedBeforeMaturity
        )
    {
        uint256 index = _getCycleFinancialIndex(cycleId);
        CycleFinancial memory cycleFinancial = CycleFinancials[index];

        return (
            cycleFinancial.underlyingTotalDeposits,
            cycleFinancial.underlyingTotalWithdrawn,
            cycleFinancial.underlyingBalance,
            cycleFinancial.derivativeBalance,
            cycleFinancial.underylingBalanceClaimedBeforeMaturity,
            cycleFinancial.derivativeBalanceClaimedBeforeMaturity
        );
    }

    function getCycleMember(uint256 index)
        external
        view
        returns (
            uint256 cycleId,
            uint256 groupId,
            address payable _address,
            uint256 totalLiquidityAsPenalty,
            uint256 numberOfCycleStakes,
            uint256 stakesClaimed,
            bool hasWithdrawn
        )
    {
        CycleMember memory cycleMember = _getCycleMember(index);

        return (
            cycleMember.cycleId,
            cycleMember.groupId,
            cycleMember._address,
            cycleMember.totalLiquidityAsPenalty,
            cycleMember.numberOfCycleStakes,
            cycleMember.stakesClaimed,
            cycleMember.hasWithdrawn
        );
    }

    function getCycles() external view returns (Cycle[] memory) {
        return Cycles;
    }

    function getCyclesLength() external view returns (uint256) {
        return Cycles.length;
    }

    function createCycleMember(
        uint256 cycleId,
        uint256 groupId,
        uint256 totalLiquidityAsPenalty,
        uint256 numberOfCycleStakes,
        uint256 stakesClaimed,
        address payable depositor,
        bool hasWithdrawn
    ) external onlyStorageOracle {
        bool exist = _doesCycleMemberExist(cycleId, depositor);
        require(!exist, "Cycle member already exist");

        CycleMember memory cycleMember =
            CycleMember(
                cycleId,
                groupId,
                totalLiquidityAsPenalty,
                numberOfCycleStakes,
                stakesClaimed,
                true,
                 depositor,
                hasWithdrawn
            );

        uint256 index = CycleMembers.length;

        RecordIndex memory recordIndex = RecordIndex(true, index);

        CycleMembers.push(cycleMember);
        CycleMembersIndexer[cycleId].push(recordIndex);
        CycleMembersIndexerByDepositor[depositor].push(recordIndex);

        CycleMembersDeepIndexer[cycleId][depositor] = recordIndex;
    }

    function updateCycleMember(
        uint256 cycleId,
        address payable depositor,
        uint256 totalLiquidityAsPenalty,
        uint256 numberOfCycleStakes,
        uint256 stakesClaimed,
        bool hasWithdrawn
    ) external onlyStorageOracle {
        CycleMember memory cycleMember = _getCycleMember(cycleId, depositor);
        cycleMember._address = depositor;
        cycleMember.totalLiquidityAsPenalty = totalLiquidityAsPenalty;
        cycleMember.numberOfCycleStakes = numberOfCycleStakes;
        cycleMember.stakesClaimed = stakesClaimed;
        cycleMember.hasWithdrawn = hasWithdrawn;

        _updateCycleMember(cycleMember);
    }

    function createCycle(
        uint256 groupId,
        uint256 numberOfDepositors,
        uint256 startTimeStamp,
        uint256 duration,
        uint256 maximumSlots,
        bool hasMaximumSlots,
        uint256 cycleStakeAmount,
        uint256 totalStakes,
        uint256 stakesClaimed,
        CycleStatus cycleStatus,
        uint256 stakesClaimedBeforeMaturity
    ) external onlyStorageOracle returns (uint256) {
        lastCycleId += 1;
        Cycle memory cycle =
            Cycle(
                lastCycleId,
                groupId,
                numberOfDepositors,
                startTimeStamp,
                duration,
                maximumSlots,
                cycleStakeAmount,
                totalStakes,
                stakesClaimed,
                hasMaximumSlots,
                true,
                cycleStatus,
                stakesClaimedBeforeMaturity
            );

        uint256 index = Cycles.length;
        RecordIndex memory recordIndex = RecordIndex(true, index);

        Cycles.push(cycle);
        CycleIndexer[lastCycleId] = recordIndex;
        GroupCycleIndexer[cycle.groupId].push(recordIndex);
        return lastCycleId;
    }

    function createCycleFinancials(
        uint256 cycleId,
        uint256 groupId,
        uint256 underlyingTotalDeposits,
        uint256 underlyingTotalWithdrawn,
        uint256 underlyingBalance,
        uint256 derivativeBalance,
        uint256 underylingBalanceClaimedBeforeMaturity,
        uint256 derivativeBalanceClaimedBeforeMaturity
    ) external onlyStorageOracle {
        RecordIndex memory recordIndex = CycleIndexer[cycleId];
        require(recordIndex.exists, "Cycle not found");
        CycleFinancial memory cycleFinancial =
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
        CycleFinancials.push(cycleFinancial);
        CycleFinancialsIndexer[cycleId] = recordIndex;
        GroupCycleFinancialsIndexer[groupId].push(recordIndex);
    }

    function updateCycle(
        uint256 cycleId,
        uint256 numberOfDepositors,
        uint256 startTimeStamp,
        uint256 duration,
        uint256 maximumSlots,
        bool hasMaximumSlots,
        uint256 cycleStakeAmount,
        uint256 totalStakes,
        uint256 stakesClaimed,
        CycleStatus cycleStatus,
        uint256 stakesClaimedBeforeMaturity
    ) external onlyStorageOracle {
        Cycle memory cycle = _getCycle(cycleId);
        cycle.numberOfDepositors = numberOfDepositors;
        cycle.cycleStartTimeStamp = startTimeStamp;
        cycle.cycleDuration = duration;
        cycle.maximumSlots = maximumSlots;
        cycle.hasMaximumSlots = hasMaximumSlots;
        cycle.cycleStakeAmount = cycleStakeAmount;

        cycle.totalStakes = totalStakes;
        cycle.stakesClaimed = stakesClaimed;
        cycle.cycleStatus = cycleStatus;
        cycle.stakesClaimedBeforeMaturity = stakesClaimedBeforeMaturity;

        _updateCycle(cycle);
    }

    function updateCycleFinancials(
        uint256 cycleId,
        uint256 underlyingTotalDeposits,
        uint256 underlyingTotalWithdrawn,
        uint256 underlyingBalance,
        uint256 derivativeBalance,
        uint256 underylingBalanceClaimedBeforeMaturity,
        uint256 derivativeBalanceClaimedBeforeMaturity
    ) external onlyStorageOracle {
        uint256 index = _getCycleFinancialIndex(cycleId);

        CycleFinancial memory cycleFinancial = CycleFinancials[index];
        cycleFinancial.underlyingTotalDeposits = underlyingTotalDeposits;
        cycleFinancial.underlyingTotalWithdrawn = underlyingTotalWithdrawn;
        cycleFinancial.underlyingBalance = underlyingBalance;
        cycleFinancial.derivativeBalance = derivativeBalance;
        cycleFinancial
            .underylingBalanceClaimedBeforeMaturity = underylingBalanceClaimedBeforeMaturity;
        cycleFinancial
            .derivativeBalanceClaimedBeforeMaturity = derivativeBalanceClaimedBeforeMaturity;
        _updateCycleFinancial(cycleFinancial);
    }

    function getCycleIndex(uint256 cycleId) external view returns (uint256) {
        return _getCycleIndex(cycleId);
    }

    function getCycleFinancialIndex(uint256 cycleId)
        external
        view
        returns (uint256)
    {
        return _getCycleFinancialIndex(cycleId);
    }

    function _getCycleIndex(uint256 cycleId) internal view returns (uint256) {
        bool doesCycleExist = CycleIndexer[cycleId].exists;
        require(doesCycleExist, "Cycle not found");

        return CycleIndexer[cycleId].index;
    }

      function getRecordIndexForGroupCycle(
        uint256 groupId,
        uint256 recordIndexLocation
    ) external view returns (bool, uint256) {

            RecordIndex memory recordIndex
         = GroupCycleIndexer[groupId][recordIndexLocation];
        return (recordIndex.exists, recordIndex.index);
    }

    function getRecordIndexForCycleMembersIndexerByDepositor(
        address depositorAddress,
        uint256 recordIndexLocation
    ) external view returns (bool, uint256) {
        RecordIndex memory recordIndex =
            CycleMembersIndexerByDepositor[depositorAddress][
                recordIndexLocation
            ];

        return (recordIndex.exists, recordIndex.index);
    }

    function getRecordIndexForCycleMembersIndexer(
        uint256 cycleId,
        uint256 recordIndexLocation
    ) external view returns (bool, uint256) {
        RecordIndex memory recordIndex =
            CycleMembersIndexer[cycleId][recordIndexLocation];
        return (recordIndex.exists, recordIndex.index);
    }

    function getRecordIndexLengthForCycleMembers(uint256 cycleId)
        external
        view
        returns (uint256)
    {
        return CycleMembersIndexer[cycleId].length;
    }

    function getRecordIndexLengthForGroupCycleIndexer(uint256 groupId)
        external
        view
        returns (uint256)
    {
        return GroupCycleIndexer[groupId].length;
    }

    function getRecordIndexLengthForCycleMembersByDepositor(
        address depositorAddress
    ) external view returns (uint256) {
        return CycleMembersIndexerByDepositor[depositorAddress].length;
    }

    function getCycleMemberIndex(uint256 cycleId, address payable memberAddress)
        external
        view
        returns (uint256)
    {
        return _getCycleMemberIndex(cycleId, memberAddress);
    }

    function _getCycleMember(uint256 cycleId, address payable depositor)
        internal
        view
        returns (CycleMember memory)
    {
        uint256 index = _getCycleMemberIndex(cycleId, depositor);
        return _getCycleMember(index);
    }

    function _getCycleMember(uint256 index)
        internal
        view
        returns (CycleMember memory)
    {
        return CycleMembers[index];
    }

    function _getCycleMemberIndex(uint256 cycleId, address payable depositor)
        internal
        view
        returns (uint256)
    {
        bool doesCycleMemberExist =
            CycleMembersDeepIndexer[cycleId][depositor].exists;
        require(doesCycleMemberExist, "Cycle member not found");

        return CycleMembersDeepIndexer[cycleId][depositor].index;
    }

    function _getCycleFinancialIndex(uint256 cycleId)
        internal
        view
        returns (uint256)
    {
        bool doesCycleFinancialExist = CycleFinancialsIndexer[cycleId].exists;
        require(doesCycleFinancialExist, "Cycle financials not found");

        return CycleFinancialsIndexer[cycleId].index;
    }

    function _updateCycleMember(CycleMember memory cycleMember) internal {
        uint256 index =
            _getCycleMemberIndex(cycleMember.cycleId, cycleMember._address);
        CycleMembers[index] = cycleMember;
    }

    function _updateCycle(Cycle memory cycle) internal {
        uint256 index = _getCycleIndex(cycle.id);
        Cycles[index] = cycle;
    }

    function _updateCycleFinancial(CycleFinancial memory cycleFinancial)
        internal
    {
        uint256 index = _getCycleIndex(cycleFinancial.cycleId);
        CycleFinancials[index] = cycleFinancial;
    }

    function _getCycle(uint256 cycleId) internal view returns (Cycle memory) {
        uint256 index = _getCycleIndex(cycleId);

        return Cycles[index];
    }

    function _getCycleFinancial(uint256 cycleId)
        internal
        view
        returns (CycleFinancial memory)
    {
        uint256 index = _getCycleFinancialIndex(cycleId);

        CycleFinancial memory cycleFinancial = CycleFinancials[index];
        return cycleFinancial;
    }

    function doesCycleMemberExist(uint256 cycleId, address depositor)
        external
        view
        returns (bool)
    {
        return _doesCycleMemberExist(cycleId, depositor);
    }

    function _doesCycleMemberExist(uint256 cycleId, address depositor)
        internal
        view
        returns (bool)
    {
        return CycleMembersDeepIndexer[cycleId][depositor].exists;
    }
}
