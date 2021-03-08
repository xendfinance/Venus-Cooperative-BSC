pragma solidity ^0.6.6;
import "./IClientRecordShema.sol";
pragma experimental ABIEncoderV2;

interface IClientRecord is IClientRecordSchema {
    function doesClientRecordExist(address depositor)
        external
        view
        returns (bool);

    function getRecordIndex(address depositor) external view returns (uint256);

    function createClientRecord(
        address payable _address,
        uint256 underlyingTotalDeposits,
        uint256 underlyingTotalWithdrawn,
        uint256 derivativeBalance,
        uint256 derivativeTotalDeposits,
        uint256 derivativeTotalWithdrawn
    ) external;

    function updateClientRecord(
        address payable _address,
        uint256 underlyingTotalDeposits,
        uint256 underlyingTotalWithdrawn,
        uint256 derivativeBalance,
        uint256 derivativeTotalDeposits,
        uint256 derivativeTotalWithdrawn
    ) external;

    function getLengthOfClientRecords() external view returns (uint256);

    function getClientRecordByIndex(uint256 index)
        external
        view
        returns (
            address payable _address,
            uint256 underlyingTotalDeposits,
            uint256 underlyingTotalWithdrawn,
            uint256 derivativeBalance,
            uint256 derivativeTotalDeposits,
            uint256 derivativeTotalWithdrawn
        );

    function getClientRecordByAddress(address depositor)
        external
        view
        returns (
            address payable _address,
            uint256 underlyingTotalDeposits,
            uint256 underlyingTotalWithdrawn,
            uint256 derivativeBalance,
            uint256 derivativeTotalDeposits,
            uint256 derivativeTotalWithdrawn
        );

    function activateStorageOracle(address oracle) external;

    function deactivateStorageOracle(address oracle) external;

    function reAssignStorageOracle(address newOracle) external;

     function GetRecordIndexFromDepositor(address member) external view returns(uint);
     
     function GetRecordIdFromRecordIndexAndDepositorRecord(uint recordIndex, address depositor) external view returns(uint);
      
     function CreateDepositRecordMapping(uint amount, uint lockPeriodInSeconds,uint depositDateInSeconds, address payable depositor, bool hasWithdrawn) external returns (uint);
    
     function UpdateDepositRecordMapping(uint DepositRecordId, uint amount, uint lockPeriodInSeconds,uint depositDateInSeconds, address payable depositor, bool hasWithdrawn) external;

     function GetRecordById(uint depositRecordId) external view returns(uint recordId, address payable depositorId, uint amount, uint depositDateInSeconds, uint lockPeriodInSeconds, bool hasWithdrawn);
     
     function GetRecords() external view returns (FixedDepositRecord [] memory);
     
     function CreateDepositorToDepositRecordIndexToRecordIDMapping(address payable depositor, uint recordId) external;
     
     function CreateDepositorAddressToDepositRecordMapping (address payable depositor, uint recordId, uint amountDeposited, uint lockPeriodInSeconds, uint depositDateInSeconds, bool hasWithdrawn) external;
}
