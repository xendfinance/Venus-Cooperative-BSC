pragma solidity 0.6.6;

contract StorageOwners {
    address owner;
    mapping(address => bool) private storageOracles;

    constructor() public {
        owner = msg.sender;
    }

    function changeStorageOracleStatus(address oracle, bool status) external onlyOwner {
        storageOracles[oracle] = status;
}
  function activateStorageOracle(address oracle) external onlyOwner {
        storageOracles[oracle] = true;
    }

    function deactivateStorageOracle(address oracle) external onlyOwner {
        storageOracles[oracle] = false;
    }

    function reAssignStorageOracle(address newOracle)
        external
        onlyStorageOracle
    {
        storageOracles[msg.sender] = false;
        storageOracles[newOracle] = true;
    }

    function transferOwnership(address payable newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }

        // require(newOwner == address(0), "new owneru");
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "unauthorized access to contract");
        _;
    }

    modifier onlyStorageOracle() {
        bool hasAccess = storageOracles[msg.sender];
        require(hasAccess, "unauthorized access to contract");
        _;
    }
}
