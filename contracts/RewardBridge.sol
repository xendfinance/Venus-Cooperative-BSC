pragma solidity 0.6.6;


import "./IERC20.sol";
import "./XendTokenMinters.sol";
import "./SafeMath.sol";
import "./SafeERC20.sol";
import "./Address.sol";
import "./IRewardBridge.sol";

contract RewardBridge is XendTokenMinters,IRewardBridge {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    address RewardTokenAddress;

    constructor(address rewardTokenAddress) public{
        RewardTokenAddress = rewardTokenAddress;
     
    }

    function rewardUser(uint256 amount, address recipient) external override onlyMinter{
        require(recipient!=address(0x0),"Invalid recipient address");
        uint256 balance = _balance();
        require(balance>amount,"Insufficient reward tokens in reward bridge vault");
        IERC20 tokenContract = IERC20(RewardTokenAddress);
        tokenContract.safeTransfer(recipient, amount);
    }

    function updateTokenAddress(address newTokenAddress) external override onlyOwner {
        require(newTokenAddress!=address(0x0),"Invalid token address");
        require(newTokenAddress.isContract(),"Invalid contract address");
        uint256 oldTokenAddressBalance = _balance();
        if(oldTokenAddressBalance>0){
            IERC20 tokenContract = IERC20(RewardTokenAddress);
            tokenContract.safeTransfer(msg.sender,oldTokenAddressBalance);
        }
        RewardTokenAddress = newTokenAddress;
    }

    function withdrawTokens(address tokenAddress) external override onlyOwner{
        uint256 balance = _balance(tokenAddress);
        require(balance>0,"Insufficient token balance");
        IERC20 tokenContract = IERC20(tokenAddress);
        tokenContract.safeTransfer(msg.sender,balance);
    }

    function withdrawTokens() external override onlyOwner{
        uint256 balance = _balance();
        require(balance>0,"Insufficient token balance");
        IERC20 tokenContract = IERC20(RewardTokenAddress);
        tokenContract.safeTransfer(msg.sender,balance);
    }

    function _balance(address tokenAddress) internal view returns (uint256){
        IERC20 tokenContract = IERC20(tokenAddress);
        return tokenContract.balanceOf(address(this));
    }

    function _balance() internal view returns (uint256){
        IERC20 tokenContract = IERC20(RewardTokenAddress);
        return tokenContract.balanceOf(address(this));
    }

}
