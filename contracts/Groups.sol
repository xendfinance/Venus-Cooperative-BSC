pragma solidity 0.6.6;

import "./IGroupSchema.sol";
import "./SafeMath.sol";
import "./StorageOwners.sol";


contract Groups is IGroupSchema, StorageOwners {

    using SafeMath for uint256;

    // list of group records
    Group[] private Groups;
    //Mapping that enables ease of traversal of the group records
    mapping(uint256 => RecordIndex) private GroupIndexer;

    // Mapping that enables ease of traversal of groups created by an addressor
    mapping(address => RecordIndex[]) private GroupForCreatorIndexer;

    // indexes a group location using the group name
    mapping(string => RecordIndex) private GroupIndexerByName;

    mapping(address => uint256) private XendTokensReward;

    GroupMember[] GroupMembers;

    //Mapping of a groups members. Key is the group id,
    mapping(uint256 => RecordIndex[]) private GroupMembersIndexer;

    mapping(address => RecordIndex[]) private GroupMembersIndexerByDepositor;
    mapping(uint256 => mapping(address => RecordIndex))
        private GroupMembersDeepIndexer;

    // list of group records
    Member[] private Members;

    //Mapping that enables ease of traversal of the member records. key is the member address
    mapping(address => RecordIndex) private MemberIndexer;

    uint256 lastGroupId;

    address[] tokenAddresses;
    uint256 totalEthersDeposited;
    mapping(address => uint256) totalTokensDeposited;

   function getXendTokensReward(address payable receiverAddress)
        external
        view
        returns (uint256)
    {
        return XendTokensReward[receiverAddress];
    }

   function setXendTokensReward(
        address payable receiverAddress,
        uint256 amount
    ) external {
        XendTokensReward[receiverAddress] = XendTokensReward[receiverAddress]
            .add(amount);
    }

    function getLengthOfTokenAddressesUsedInDeposit()
        external
        view
        returns (uint256)
    {
        return tokenAddresses.length;
    }

    function incrementTokenDeposit(address tokenAddress, uint256 amount)
        external
        onlyStorageOracle
        returns (uint256)
    {
        if (totalTokensDeposited[tokenAddress] == 0) {
            tokenAddresses.push(tokenAddress);
        }
        totalTokensDeposited[tokenAddress] = totalTokensDeposited[tokenAddress].add(amount);
        return totalTokensDeposited[tokenAddress];
    }

    function decrementTokenDeposit(address tokenAddress, uint256 amount)
        external
        onlyStorageOracle
        returns (uint256)
    {
        uint256 currentAmount = totalTokensDeposited[tokenAddress];
        require(
            currentAmount >= amount,
            "deposit balance overdraft is not allowed"
        );
        totalTokensDeposited[tokenAddress] = totalTokensDeposited[tokenAddress].sub(amount);
        return totalTokensDeposited[tokenAddress];
    }

    function getTokenDeposit(address tokenAddress)
        external
        view
        returns (uint256)
    {
        return totalTokensDeposited[tokenAddress];
    }

    function incrementEtherDeposit(uint256 amount)
        external
        onlyStorageOracle
        returns (uint256)
    {
        totalEthersDeposited = totalEthersDeposited.add(amount);
        return totalEthersDeposited;
    }

    function decrementEtherDeposit(uint256 amount)
        external
        onlyStorageOracle
        returns (uint256)
    {
        require(
            totalEthersDeposited >= amount,
            "deposit balance overdraft is not allowed"
        );
        totalEthersDeposited = totalEthersDeposited.sub(amount);
        return totalEthersDeposited;
    }

    function getEtherDeposit() external view returns (uint256) {
        return totalEthersDeposited;
    }

    function createMember(address payable depositor)
        external
        onlyStorageOracle
    {
        Member memory member = Member(true, depositor);

        bool exist = _doesMemberExist(depositor);

        require(!exist, "Member already exists");

        RecordIndex memory recordIndex = RecordIndex(true, Members.length);

        Members.push(member);
        MemberIndexer[depositor] = recordIndex;
    }

    function getMember(address _address) external view returns (address) {
        uint256 index = _getMemberIndex(_address);
        Member memory member = Members[index];

       return member._address;
    }

    function _getMemberIndex(address _address) internal view returns (uint256) {
        bool doesMemberExist = MemberIndexer[_address].exists;
        require(doesMemberExist, "Member not found");

       return MemberIndexer[_address].index;
      
    }

    function createGroup(
        string calldata name,
        string calldata symbol,
        address groupCreator
    ) external onlyStorageOracle returns (uint256) {
        bool exist = _doesGroupExist(name);
        require(!exist, "Group name has already been used");

        lastGroupId += 1;
        Group memory group = Group(
            lastGroupId,
            name,
            symbol,
            true,
            payable(groupCreator)
        );
        uint256 index = Groups.length;
        RecordIndex memory recordIndex = RecordIndex(true, index);
        Groups.push(group);
        GroupIndexer[lastGroupId] = recordIndex;
        GroupIndexerByName[name] = recordIndex;
        GroupForCreatorIndexer[groupCreator].push(recordIndex);

        return lastGroupId;
    }

    function updateGroup(
        uint256 id,
        string calldata name,
        string calldata symbol,
        address payable creatorAddress
    ) external onlyStorageOracle {
        uint256 index = _getGroupIndex(id);
        Groups[index].name = name;
        Groups[index].symbol = symbol;
        Groups[index].creatorAddress = creatorAddress;
    }

    function doesGroupExist(uint256 groupId) external view returns (bool) {
        return _doesGroupExist(groupId);
    }

    function _doesGroupExist(uint256 groupId) internal view returns (bool) {
       return GroupIndexer[groupId].exists;
    }

    function doesGroupExist(string calldata groupName)
        external
        view
        returns (bool)
    {
        return _doesGroupExist(groupName);
    }

    function _doesGroupExist(string memory groupName)
        internal
        view
        returns (bool)
    {
        return GroupIndexerByName[groupName].exists;

    }

    function doesMemberExist(address depositor) external view returns (bool) {
        return _doesMemberExist(depositor);
    }

    function _doesMemberExist(address depositor) internal view returns (bool) {
        return MemberIndexer[depositor].exists;
    }

    function createGroupMember(uint256 groupId, address payable depositor)
        external
        onlyStorageOracle
    {
        bool exist = _doesGroupMemberExist(groupId, depositor);
        require(!exist, "Group member exists");

        RecordIndex memory recordIndex = RecordIndex(true, GroupMembers.length);

        GroupMember memory groupMember = GroupMember(true, depositor, groupId);

        GroupMembersIndexer[groupId].push(recordIndex);
        GroupMembersIndexerByDepositor[depositor].push(recordIndex);
        GroupMembersDeepIndexer[groupId][depositor] = recordIndex;
        GroupMembers.push(groupMember);
    }

    function getGroupMember(uint256 index)
        external
        view
        returns (address payable _address, uint256 groupId)
    {
        GroupMember memory groupMember = GroupMembers[index];
        return (groupMember._address, groupMember.groupId);
    }

    function getGroupMembersDeepIndexer(uint256 groupId, address depositor)
        external
        view
        returns (bool exists, uint256 index)
    {

            RecordIndex memory recordIndex
         = GroupMembersDeepIndexer[groupId][depositor];
        return (recordIndex.exists, recordIndex.index);
    }

    function getRecordIndexLengthForGroupMembersIndexer(uint256 groupId)
        external
        view
        returns (uint256)
    {
        return GroupMembersIndexer[groupId].length;
    }

    function getRecordIndexLengthForGroupMembersIndexerByDepositor(
        address depositor
    ) external view returns (uint256) {
        return GroupMembersIndexerByDepositor[depositor].length;
    }

    function getGroupMembersIndexer(uint256 groupId, uint256 indexerLocation)
        external
        view
        returns (bool exist, uint256 index)
    {

            RecordIndex memory recordIndex
         = GroupMembersIndexer[groupId][indexerLocation];
        return (recordIndex.exists, recordIndex.index);
    }

    function getGroupMembersIndexerByDepositor(
        address depositor,
        uint256 indexerLocation
    ) external view returns (bool exist, uint256 index) {

            RecordIndex memory recordIndex
         = GroupMembersIndexerByDepositor[depositor][indexerLocation];
        return (recordIndex.exists, recordIndex.index);
    }

    function doesGroupMemberExist(uint256 groupId, address depositor)
        external
        view
        returns (bool)
    {
        return _doesGroupMemberExist(groupId, depositor);
    }

    function _doesGroupMemberExist(uint256 groupId, address depositor)
        internal
        view
        returns (bool)
    {
        return GroupMembersDeepIndexer[groupId][depositor].exists;
        
    }

    function getGroupIndexer(uint256 groupId)
        external
        view
        returns (bool exist, uint256 index)
    {
        RecordIndex memory recordIndex = GroupIndexer[groupId];
        return (recordIndex.exists, recordIndex.index);
    }

    function getRecordIndexLengthForCreator(address groupCreator)
        external
        view
        returns (uint256)
    {
        return GroupForCreatorIndexer[groupCreator].length;
    }

    function getGroupForCreatorIndexer(
        address groupCreator,
        uint256 indexerLocation
    ) external view returns (bool exist, uint256 index) {

            RecordIndex memory recordIndex
         = GroupForCreatorIndexer[groupCreator][indexerLocation];
        return (recordIndex.exists, recordIndex.index);
    }

    function getGroupIndexerByName(string calldata groupName)
        external
        view
        returns (bool exist, uint256 index)
    {
        RecordIndex memory recordIndex = GroupIndexerByName[groupName];
        return (recordIndex.exists, recordIndex.index);
    }

    function getGroupById(uint256 groupId)
        external
        view
        onlyStorageOracle
        returns (
            uint256,
            string memory,
            string memory,
            address payable
        )
    {
        uint256 index = _getGroupIndex(groupId);

        Group storage group = Groups[index];
        return (group.id, group.name, group.symbol, group.creatorAddress);
    }

    function getGroupByIndex(uint256 index)
        external
        view
        onlyStorageOracle
        returns (
            uint256,
            string memory,
            string memory,
            address payable
        )
    {
        return _getGroupByIndex(index);
    }

    function _getGroupByIndex(uint256 index)
        internal
        view
        onlyStorageOracle
        returns (
            uint256,
            string memory,
            string memory,
            address payable
        )
    {
        uint256 length = Groups.length;
        require(length > index, "Out of range");
        Group storage group = Groups[index];
        return (group.id, group.name, group.symbol, group.creatorAddress);
    }

    function getGroupIndex(uint256 groupId)
        external
        view
        onlyStorageOracle
        returns (uint256)
    {
        return _getGroupIndex(groupId);
    }

    function _getGroupIndex(uint256 groupId)
        internal
        view
        onlyStorageOracle
        returns (uint256)
    {
        bool doesGroupExist = GroupIndexer[groupId].exists;
        require(doesGroupExist, "Group not found");
        return GroupIndexer[groupId].index;
    }
}
