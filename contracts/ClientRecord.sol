pragma solidity 0.6.6;
import "./SafeMath.sol";
import "./IClientRecordShema.sol";
import "./StorageOwners.sol";
pragma experimental ABIEncoderV2;

contract ClientRecord is IClientRecordSchema, StorageOwners {

    uint256 DepositRecordId;

    using SafeMath for uint256;
    
    FixedDepositRecord[] fixedDepositRecords;
    
    mapping(uint => FixedDepositRecord) DepositRecordMapping;
    
    
    mapping (address => mapping(uint => FixedDepositRecord)) DepositRecordToDepositorMapping; //depositor address to depositor cycle mapping
    
     mapping(address=>uint) DepositorToDepositorRecordIndexMapping; //  This tracks the number of records by index created by a depositor

    mapping(address=>mapping(uint=>uint)) DepositorToRecordIndexToRecordIDMapping; //  This maps the depositor to the record index and then to the record ID

    // list of CLient Records
    ClientRecord[] ClientRecords;
    //Mapping that enables ease of traversal of the Client Records
    mapping(address => RecordIndex) public ClientRecordIndexer;

    function doesClientRecordExist(address depositor)
        external
        view
        returns (bool)
    {
       return ClientRecordIndexer[depositor].exists;
        
    }

    function getRecordIndex(address depositor) external view returns (uint256) {
        RecordIndex memory recordIndex = ClientRecordIndexer[depositor];
        require(recordIndex.exists, "member record not found");
        return recordIndex.index;
    }

    function createClientRecord(
        address payable _address,
        uint256 underlyingTotalDeposits,
        uint256 underlyingTotalWithdrawn,
        uint256 derivativeBalance,
        uint256 derivativeTotalDeposits,
        uint256 derivativeTotalWithdrawn
    ) external onlyStorageOracle {
        RecordIndex memory recordIndex = ClientRecordIndexer[_address];
        require(
            !recordIndex.exists,
            "depositor record already exists"
        );
        ClientRecord memory clientRecord = ClientRecord(
            true,
            _address,
            underlyingTotalDeposits,
            underlyingTotalWithdrawn,
            derivativeBalance,
            derivativeTotalDeposits,
            derivativeTotalWithdrawn
        );

        recordIndex = RecordIndex(true, ClientRecords.length);
        ClientRecords.push(clientRecord);
        ClientRecordIndexer[_address] = recordIndex;
    }

    function updateClientRecord(
        address payable _address,
        uint256 underlyingTotalDeposits,
        uint256 underlyingTotalWithdrawn,
        uint256 derivativeBalance,
        uint256 derivativeTotalDeposits,
        uint256 derivativeTotalWithdrawn
    ) external onlyStorageOracle {
        RecordIndex memory recordIndex = ClientRecordIndexer[_address];
        require(recordIndex.exists, "depositor record not found");
        ClientRecord memory clientRecord = ClientRecord(
            true,
            _address,
            underlyingTotalDeposits,
            underlyingTotalWithdrawn,
            derivativeBalance,
            derivativeTotalDeposits,
            derivativeTotalWithdrawn
        );
clientRecord.underlyingTotalDeposits = underlyingTotalDeposits;
clientRecord.underlyingTotalWithdrawn = underlyingTotalWithdrawn;
clientRecord.derivativeBalance = derivativeBalance;
clientRecord.derivativeTotalDeposits = derivativeTotalDeposits;
clientRecord.derivativeTotalWithdrawn = derivativeTotalWithdrawn;
    }

    function getLengthOfClientRecords() external returns (uint256) {
        return ClientRecords.length;
    }

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
        )
    {
        ClientRecord memory clientRecord = ClientRecords[index];
        return (
            clientRecord._address,
            clientRecord.underlyingTotalDeposits,
            clientRecord.underlyingTotalWithdrawn,
            clientRecord.derivativeBalance,
            clientRecord.derivativeTotalDeposits,
            clientRecord.derivativeTotalWithdrawn
        );
    }

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
        )
    {
        RecordIndex memory recordIndex = ClientRecordIndexer[depositor];
        require(recordIndex.exists, "depositor record not found");
        uint256 index = recordIndex.index;

        ClientRecord memory clientRecord = ClientRecords[index];
        return (
            clientRecord._address,
            clientRecord.underlyingTotalDeposits,
            clientRecord.underlyingTotalWithdrawn,
            clientRecord.derivativeBalance,
            clientRecord.derivativeTotalDeposits,
            clientRecord.derivativeTotalWithdrawn
        );
    }

      function GetRecordIndexFromDepositor(address member) external view returns(uint){

        return DepositorToDepositorRecordIndexMapping[member];
    }
    
     function GetRecordIdFromRecordIndexAndDepositorRecord(uint256 recordIndex, address depositor) external view returns(uint){

      mapping(uint=>uint) storage depositorCreatedRecordIndexToRecordId = DepositorToRecordIndexToRecordIDMapping[depositor];

      return depositorCreatedRecordIndexToRecordId[recordIndex];
    }
    
     function CreateDepositRecordMapping(uint256 amount, uint256 lockPeriodInSeconds,uint256 depositDateInSeconds, address payable depositor, bool hasWithdrawn) external onlyStorageOracle returns(uint)   {
          
          DepositRecordId += 1;

         FixedDepositRecord storage _fixedDeposit = DepositRecordMapping[DepositRecordId];

        _fixedDeposit.recordId = DepositRecordId;
        _fixedDeposit.amount = amount;
        _fixedDeposit.lockPeriodInSeconds = lockPeriodInSeconds;
        _fixedDeposit.depositDateInSeconds = depositDateInSeconds;
        _fixedDeposit.hasWithdrawn = hasWithdrawn;
        _fixedDeposit.depositorId = depositor;
        
        fixedDepositRecords.push(_fixedDeposit);

    return DepositRecordId;
    }

     function UpdateDepositRecordMapping(uint256 depositRecordId, uint256 amount, uint256 lockPeriodInSeconds,uint256 depositDateInSeconds, address payable depositor, bool hasWithdrawn) external onlyStorageOracle  {
         
         
         FixedDepositRecord storage _fixedDeposit = DepositRecordMapping[depositRecordId];

        _fixedDeposit.recordId = depositRecordId;
        _fixedDeposit.amount = amount;
        _fixedDeposit.lockPeriodInSeconds = lockPeriodInSeconds;
        _fixedDeposit.depositDateInSeconds = depositDateInSeconds;
        _fixedDeposit.hasWithdrawn = hasWithdrawn;
        _fixedDeposit.depositorId = depositor;
        
        fixedDepositRecords.push(_fixedDeposit);


    }
    
   function GetRecordId() external view returns (uint){
        return DepositRecordId;
    }
    
    function GetRecordById(uint depositRecordId) external view returns(uint recordId, address payable depositorId, uint amount, uint depositDateInSeconds, uint lockPeriodInSeconds, bool hasWithdrawn) {
        
        FixedDepositRecord memory records = DepositRecordMapping[depositRecordId];
        
        return(records.recordId, records.depositorId, records.amount, records.depositDateInSeconds, records.lockPeriodInSeconds, records.hasWithdrawn);
    }
    
    function GetRecords() external view returns (FixedDepositRecord [] memory) {
        return fixedDepositRecords;
    }
    
     function CreateDepositorToDepositRecordIndexToRecordIDMapping(address payable depositor, uint recordId) external onlyStorageOracle {
      
      DepositorToDepositorRecordIndexMapping[depositor] = DepositorToDepositorRecordIndexMapping[depositor].add(1);

      uint DepositorCreatedRecordIndex = DepositorToDepositorRecordIndexMapping[depositor];
      mapping(uint=>uint) storage depositorCreatedRecordIndexToRecordId = DepositorToRecordIndexToRecordIDMapping[depositor];
      depositorCreatedRecordIndexToRecordId[DepositorCreatedRecordIndex] = recordId;
    }
    
    function CreateDepositorAddressToDepositRecordMapping (address payable depositor, uint recordId, uint amountDeposited, uint lockPeriodInSeconds, uint depositDateInSeconds, bool hasWithdrawn) external onlyStorageOracle {
        mapping(uint => FixedDepositRecord) storage depositorAddressMapping = DepositRecordToDepositorMapping[depositor];
        
        depositorAddressMapping[recordId].recordId = recordId;
        depositorAddressMapping[recordId].depositorId = depositor;
        depositorAddressMapping[recordId].amount = amountDeposited;
        depositorAddressMapping[recordId].depositDateInSeconds = depositDateInSeconds;
        depositorAddressMapping[recordId].lockPeriodInSeconds = lockPeriodInSeconds;
        depositorAddressMapping[recordId].hasWithdrawn = hasWithdrawn;
        
    }
}
