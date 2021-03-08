pragma solidity 0.6.6;

interface IGroupSchema {
    struct Group {
        uint256 id;
        string name;
        string symbol;
        bool exists;
        address payable creatorAddress;
    }

    struct Cycle {
        uint256 id;
        uint256 groupId;
        uint256 numberOfDepositors;
        uint256 cycleStartTimeStamp;
        uint256 cycleDuration;
        uint256 maximumSlots;
        uint256 cycleStakeAmount;
        // represents the total stakes of every cycle member deposits
        uint256 totalStakes;
        //represents the total stakes of every cycle member withdrawal
        uint256 stakesClaimed;
        bool hasMaximumSlots;
        bool exists;
        CycleStatus cycleStatus;
        // represents the number of cycle stakes that user's have cashed out on before the cycle has ended
        uint256 stakesClaimedBeforeMaturity;
    }

    struct CycleFinancial {
        bool exists;
        uint256 cycleId;
        //total underlying asset deposited into contract
        uint256 underlyingTotalDeposits;
        //total underlying asset that have been withdrawn by cycle members
        uint256 underlyingTotalWithdrawn;
        // underlying amount gotten after lending period has ended and shares have been reedemed for underlying asset;
        uint256 underlyingBalance;
        // lending shares representation of amount deposited in lending protocol
        uint256 derivativeBalance;
        // represents the total underlying crypto amount that has been cashed out before the cycle ended
        uint256 underylingBalanceClaimedBeforeMaturity;
        // represents the total derivative crypto amount that has been cashed out on before the cycle ended
        uint256 derivativeBalanceClaimedBeforeMaturity;
    }

    struct CycleMember {
        uint256 cycleId;
        uint256 groupId;
        uint256 totalLiquidityAsPenalty;
        uint256 numberOfCycleStakes;
        uint256 stakesClaimed;
        bool exist;
        address payable _address;
        bool hasWithdrawn;
    }

    struct Member {
        bool exists;
        address payable _address;
    }

    struct GroupMember {
        bool exists;
        address payable _address;
        uint256 groupId;
    }

    struct RecordIndex {
        bool exists;
        uint256 index;
    }

    enum CycleStatus {NOT_STARTED, ONGOING, ENDED}
}
