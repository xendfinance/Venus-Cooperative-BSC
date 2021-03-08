pragma solidity ^0.6.6;
import "./IGroupSchema.sol";
pragma experimental ABIEncoderV2;

interface ICycles is IGroupSchema {

    function getCycles() external view returns (Cycle [] memory);

    function getCyclesLength() external view returns (uint256);

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
        );

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
        );

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
        );

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
        );

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
        );

    function createCycleMember(
        uint256 cycleId,
        uint256 groupId,
        address payable depositor,
        uint256 totalLiquidityAsPenalty,
        uint256 numberOfCycleStakes,
        uint256 stakesClaimed,
        bool hasWithdrawn
    ) external;

    function updateCycleMember(
        uint256 cycleId,
        uint256 totalLiquidityAsPenalty,
        uint256 numberOfCycleStakes,
        uint256 stakesClaimed,
         address payable depositor,
        bool hasWithdrawn
    ) external;

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
    ) external returns (uint256);

    function createCycleFinancials(
        uint256 cycleId,
        uint256 groupId,
        uint256 underlyingTotalDeposits,
        uint256 underlyingTotalWithdrawn,
        uint256 underlyingBalance,
        uint256 derivativeBalance,
        uint256 underylingBalanceClaimedBeforeMaturity,
        uint256 derivativeBalanceClaimedBeforeMaturity
    ) external;

    function updateCycle(
        uint256 cycleId,
        uint256 numberOfDepositors,
        uint256 startTimeStamp,
        uint256 duration,
        uint256 maximumSlots,
        uint256 cycleStakeAmount,
        uint256 totalStakes,
        uint256 stakesClaimed,
         bool hasMaximumSlots,
        CycleStatus cycleStatus,
        uint256 stakesClaimedBeforeMaturity
    ) external;

    function updateCycleFinancials(
        uint256 cycleId,
        uint256 underlyingTotalDeposits,
        uint256 underlyingTotalWithdrawn,
        uint256 underlyingBalance,
        uint256 derivativeBalance,
        uint256 underylingBalanceClaimedBeforeMaturity,
        uint256 derivativeBalanceClaimedBeforeMaturity
    ) external;

    function getCycleIndex(uint256 cycleId) external view returns (uint256);

    function getCycleFinancialIndex(uint256 cycleId)
        external
        view
        returns (uint256);

    function getRecordIndexForCycleMembersIndexerByDepositor(
        uint256 cycleId,
        uint256 recordIndexLocation
    ) external view returns (bool, uint256);

    function getRecordIndexForCycleMembersIndexer(
        address depositorAddress,
        uint256 recordIndexLocation
    ) external view returns (bool, uint256);

    function getRecordIndexLengthForCycleMembers(uint256 cycleId)
        external
        view
        returns (uint256);

    function getRecordIndexLengthForGroupCycleIndexer(uint256 groupId)
        external
        view
        returns (uint256);

    function getRecordIndexLengthForCycleMembersByDepositor(
        address depositorAddress
    ) external view returns (uint256);

    function getCycleMemberIndex(uint256 cycleId, address payable memberAddress)
        external
        view
        returns (uint256);

    function doesCycleMemberExist(uint256 cycleId, address depositor)
        external
        view
        returns (bool);

    function activateStorageOracle(address oracle) external;

    function deactivateStorageOracle(address oracle) external;

    function reAssignStorageOracle(address newOracle) external;
}
