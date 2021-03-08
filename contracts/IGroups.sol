pragma solidity ^0.6.6;
import "./IGroupSchema.sol";

interface IGroups is IGroupSchema {

    function getXendTokensReward(address payable receiverAddress)
        external
        view
        returns (uint256);

    function setXendTokensReward(address payable depositorAddress, uint256 amount)
        external;
    function getLengthOfTokenAddressesUsedInDeposit()
        external
        view
        returns (uint256);

    function incrementTokenDeposit(address tokenAddress, uint256 amount)
        external
        returns (uint256);

    function decrementTokenDeposit(address tokenAddress, uint256 amount)
        external
        returns (uint256);

    function getTokenDeposit(address tokenAddress)
        external
        view
        returns (uint256);

    function incrementEtherDeposit(uint256 amount) external returns (uint256);

    function decrementEtherDeposit(uint256 amount) external returns (uint256);

    function getEtherDeposit() external view returns (uint256);

    function createMember(address payable depositor) external;

    function getMember(address _address) external view returns (address);

    function createGroup(
        string calldata name,
        string calldata symbol,
        address groupCreator
    ) external returns (uint256);

    function updateGroup(
        uint256 id,
        string calldata name,
        string calldata symbol,
        address payable creatorAddress0
    ) external;

    function doesGroupExist(uint256 groupId) external view returns (bool);

    function doesGroupExist(string calldata groupName)
        external
        view
        returns (bool);

    function doesMemberExist(address depositor) external view returns (bool);

    function createGroupMember(uint256 groupId, address payable depositor)
        external;

    function getGroupMember(uint256 index)
        external
        view
        returns (address payable _address, uint256 groupId);

    function getGroupMembersDeepIndexer(uint256 groupId, address depositor)
        external
        view
        returns (bool exists, uint256 index);

    function getRecordIndexLengthForGroupMembersIndexer(uint256 groupId)
        external
        view
        returns (uint256);

    function getRecordIndexLengthForGroupMembersIndexerByDepositor(
        address depositor
    ) external view returns (uint256);

    function getGroupMembersIndexer(uint256 groupId, uint256 indexerLocation)
        external
        view
        returns (bool exist, uint256 index);

    function getGroupMembersIndexerByDepositor(
        address depositor,
        uint256 indexerLocation
    ) external view returns (bool exist, uint256 index);

    function doesGroupMemberExist(uint256 groupId, address depositor)
        external
        view
        returns (bool);

    function getGroupIndexer(uint256 groupId)
        external
        view
        returns (bool exist, uint256 index);

    function getRecordIndexLengthForCreator(address groupCreator)
        external
        view
        returns (uint256);

    function getGroupForCreatorIndexer(
        address groupCreator,
        uint256 indexerLocation
    ) external view returns (bool exist, uint256 index);

    function getGroupIndexerByName(string calldata groupName)
        external
        view
        returns (bool exist, uint256 index);

    function getGroupById(uint256 groupId)
        external
        view
        returns (
            uint256,
            string memory,
            string memory,
            address payable
        );

    function getGroupByIndex(uint256 index)
        external
        view
        returns (
            uint256,
            string memory,
            string memory,
            address payable
        );

    function getGroupIndex(uint256 groupId) external view returns (uint256);

    function activateStorageOracle(address oracle) external;

    function deactivateStorageOracle(address oracle) external;

    function reAssignStorageOracle(address newOracle) external;
}
