// SPDX-License-Identifier: MIT
pragma solidity 0.6.6;

import "./Ownable.sol";
import "./IERC20.sol";

/*
    @brief: This contract 
*/
contract Treasury is Ownable {

    event TokenDepositEvent(
        address indexed depositorAddress,
        address indexed tokenContractAddress,
        uint256 amount
    );
    event EtherDepositEvent(address indexed depositorAddress, uint256 amount);

    enum DeositType {ETHER, TOKEN}

    receive() external payable {
        require(msg.value != 0, "Cannot deposit nothing into the treasury");
        emit EtherDepositEvent(msg.sender, msg.value);
    }

    function depositToken(address token) public payable {
        require(token != address(0x0), "token contract address cannot be null");

        require(
            address(token) != address(0),
            "tken contract address cannot be 0"
        );

        IERC20 tokenContract = IERC20(token);
        uint256 amountToDeposit = tokenContract.allowance(
            msg.sender,
            address(this)
        );

        require(
            amountToDeposit != 0,
            "Cannot deposit nothing into the treasury"
        );

        bool isSuccessful = tokenContract.transferFrom(
            msg.sender,
            address(this),
            amountToDeposit
        );
        require(isSuccessful == true, "Failed token deposit attempt");
        emit TokenDepositEvent(msg.sender, token, amountToDeposit);
    }

    function getEtherBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getTokenBalance(address token) public view returns (uint256) {
        require(token != address(0x0), "token contract address cannot be null");

        require(
            address(token) != address(0),
            "tken contract address cannot be 0"
        );

        IERC20 tokenContract = IERC20(token);
        return tokenContract.balanceOf(address(this));
    }

    function withdrawEthers(uint256 amount) external {
        uint256 etherBalance = address(this).balance;
        require(etherBalance >= amount, "Insufficient ether balance");
        owner.transfer(amount);
    }

    function withdrawTokens(address tokenAddress, uint256 amount) external {
        IERC20 tokenContract = IERC20(tokenAddress);
        uint256 tokenBalance = tokenContract.balanceOf(address(this));
        require(tokenBalance >= amount, "Insufficient token balance");
        bool isSuccessful = tokenContract.transfer(owner, amount);
        require(isSuccessful == true, "Failed token withdrawal");
    }
}
