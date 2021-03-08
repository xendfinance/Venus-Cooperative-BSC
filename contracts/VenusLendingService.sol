pragma solidity 0.6.6;

import "./VenusAdapter.sol";

contract VenusLendingService {
    address _owner;
    address _delegateContract;

    VenusAdapter _venusLendingAdapter;

    constructor() public {
        _owner = msg.sender;
    }

    function transferOwnership(address account) external onlyOwner() {
        if (_owner != address(0)) _owner = account;
    }

    function updateAdapter(address adapterAddress) external onlyOwner() {
        _venusLendingAdapter = VenusAdapter(adapterAddress);
    }

    /*
        account: this is the owner of the DUSD token
    */
    /*
        -   Before calling this function, ensure that the msg.sender or caller has given this contract address
            approval to transfer money on its behalf to another address
    */
    function Save(uint256 amount) external {
        _venusLendingAdapter.save(amount, msg.sender);
    }

    function Withdraw(uint256 amount) external {
        _venusLendingAdapter.Withdraw(amount, msg.sender);
    }

    function WithdrawByShares(uint256 amount, uint256 sharesAmount) external {
        _venusLendingAdapter.WithdrawByShares(amount, msg.sender, sharesAmount);
    }

    function WithdrawBySharesOnly(uint256 sharesAmount) external {
        _venusLendingAdapter.WithdrawBySharesOnly(msg.sender, sharesAmount);
    }

    function UserDAIBalance(address user) external view returns (uint256) {
        return _venusLendingAdapter.GetDAIBalance(user);
    }

    function UserShares(address user) external view returns (uint256) {
        return _venusLendingAdapter.GetVDaiBalance(user);
    }

    function GetVenusLendingAdapterAddress() external view returns (address) {
        return address(_venusLendingAdapter);
    }
    function GetPricePerFullShare() external view returns (uint256){
        
        return _venusLendingAdapter.GetPricePerFullShare();
    }

      modifier onlyOwner() {
        require(_owner == msg.sender, "Only owner can make this call");
        _;
    }
}
