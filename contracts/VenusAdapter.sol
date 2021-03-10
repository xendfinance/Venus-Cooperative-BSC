pragma solidity 0.6.6;

import "./IVBUSD.sol";
import "./SafeMath.sol";
import "./OwnableService.sol";
import "./ReentrancyGuard.sol";
import "./SafeERC20.sol";


contract VenusAdapter is OwnableService, ReentrancyGuard{
    
    using SafeMath for uint256;
    
    using SafeERC20 for IERC20; 

    using SafeERC20 for IVBUSD; 

     IVBUSD immutable _vBUSD;

     IERC20 immutable _BUSD;

     constructor(address payable serviceContract) public OwnableService(serviceContract){
        _vBUSD = IVBUSD(0x95c78222B3D6e262426483D42CfA53685A67Ab9D); // Venus BUSD Shares
        _BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56); // Pegged-BUSD address on BSC Main Network
     }
    

    mapping(address => uint256) userDAIdeposits;

    function GetPricePerFullShare() external view returns (uint256){

        uint256 cash = _vBUSD.getCash();

        uint256 totalBorrows = _vBUSD.totalBorrows();

        uint256 totalReserves = _vBUSD.totalReserves();

        uint256 totalSupply = _vBUSD.totalSupply();
        
        uint256 pricePerFullShare = (cash.add(totalBorrows).sub(totalReserves)).div(totalSupply);
        return pricePerFullShare;   
         }

    function GetCash() external view returns (uint256) {
        return _vBUSD.getCash();
    }
     function TotalBorrows() external view returns (uint256) {
        return _vBUSD.totalBorrows();
    }

     function TotalReserves() external view returns (uint256) {
        return _vBUSD.totalReserves();
    }
     function TotalSupply() external view returns (uint256) {
        return _vBUSD.totalSupply();
    }
 
    
    
    function GetDAIBalance(address account) external view returns (uint256){
        return _BUSD.balanceOf(account);
    }
    

    function GetVDaiBalance(address account) public view returns (uint256) {
        return _vBUSD.balanceOf(account);
    }

    /*
        account: this is the owner of the DAi token
    */
    function save(uint256 amount, address account)
        public nonReentrant
        onlyOwnerAndServiceContract
    {
        //  Give allowance that a spender can spend on behalf of the owner. NOTE: This approve function has to be called from outside this smart contract because if you call
        //  it from the smart contract, it will use the smart contract address as msg.sender which is not what we want,
        //  we want the address with the DAI token to be the one that will be msg.sender. Hence the line below will not work and needs to be called
        //  from Javascript or C# environment
        //   dai.approve(address(this),amount); (Not work)

        //  See example with Node.js below
        //  await daiContract.methods.approve("recipient(in our case, this smart contract address)",1000000).send({from: "wallet address with DAI"});

        //  Transfer DAI from the account address to this smart contract address
        _BUSD.safeTransferFrom(account, address(this), amount);

        //  This gives the yDAI contract approval to invest our DAI
        _save(amount, account);
    }

    //  This function returns your DAI balance + interest. NOTE: There is no function in Yearn finance that gives you the direct balance of DAI
    //  So you have to get it in two steps

    function GetGrossRevenue(address account) public view returns (uint256) {
        //  Get the price per full share
        uint256 price = _vBUSD.exchangeRateCurrent();

        //  Get the balance of yDai in this users address
        uint256 balanceShares = _vBUSD.balanceOf(account);

        return balanceShares.mul(price);
    }

    function GetNetRevenue(address account) public view returns (uint256) {
        uint256 grossBalance = GetGrossRevenue(account);

        uint256 userDaiDepositsBalance = userDAIdeposits[account].mul(1e18); // multiply dai deposit by 1 * 10 ^ 18 to get value in 10 ^36

        return grossBalance.sub(userDaiDepositsBalance);
    }

    function Withdraw(uint256 amount, address owner)
        public 
        nonReentrant onlyOwnerAndServiceContract
    {
        //  To withdraw our DAi amount, the amount argument is in DAi but the withdraw function of the vDai expects amount in vDai
        //  So we need to find our balance in vDai

        uint256 balanceShares = _vBUSD.balanceOf(owner);

        //  transfer vDai shares From owner to this contract address
        _vBUSD.safeTransferFrom(owner, address(this), balanceShares);

        //  We now call the withdraw function to withdraw the total DAi we have. This withdrawal is sent to this smart contract
        _withdrawBySharesAndAmount(owner,balanceShares,amount);

        //  If we have some DAi left after transferring a specified amount to a recipient, we can re-invest it in yearn finance
        uint256 balanceDai = _BUSD.balanceOf(address(this));

        if (balanceDai > 0) {
            //  This gives the _vBUSD contract approval to invest our DAi
            _save(balanceDai, owner);
        }
    }

    function WithdrawByShares(
        uint256 amount,
        address owner,
        uint256 sharesAmount
    ) public
    nonReentrant onlyOwnerAndServiceContract
    {
        //  To withdraw our DAI amount, the amount argument is in DAI but the withdraw function of the yDAI expects amount in yDAI token

        uint256 balanceShares = sharesAmount;

        //  transfer _vBUSD From owner to this contract address
        _vBUSD.safeTransferFrom(owner, address(this), balanceShares);

        //  We now call the withdraw function to withdraw the total DAi we have. This withdrawal is sent to this smart contract
        _withdrawBySharesAndAmount(owner,balanceShares,amount);

        //  If we have some DAI left after transferring a specified amount to a recipient, we can re-invest it in yearn finance
        uint256 balanceDai = _BUSD.balanceOf(address(this));

        if (balanceDai > 0) {
            //  This gives the yDAI contract approval to invest our DAI
            _save(balanceDai, owner);
        }
    }

    /*
        this function withdraws all the dai to this contract based on the sharesAmount passed
    */
    function WithdrawBySharesOnly(address owner, uint256 sharesAmount)
        public
        nonReentrant onlyOwnerAndServiceContract
    {
        uint256 balanceShares = sharesAmount;

        //  transfer _vBUSD shares From owner to this contract address
        _vBUSD.safeTransferFrom(owner, address(this), balanceShares);

        //  We now call the withdraw function to withdraw the total DAI we have. This withdrawal is sent to this smart contract
        _withdrawBySharesOnly(owner,balanceShares);

    }

    //  This function is an internal function that enabled DAI contract where user has money to approve the yDai contract address to invest the user's DAI
    //  and to send the yDai shares to the user's address
    function _save(uint256 amount, address account) internal {
        //  Approve the vDai contract address to spend amount of DAi
        _BUSD.approve(address(_vBUSD), amount);

        //  Now our yDAI contract has deposited our DAI and it is earning interest and this gives us yDAI token in this Wallet contract
        //  and we will use the yDAI token to redeem our DAI
        _vBUSD.mint(amount);

        //  call balanceOf and get the total balance of vDai shares in this contract
        uint256 shares = _vBUSD.balanceOf(address(this));

        //  transfer the _vBUSD shares to the user's address
        _vBUSD.safeTransfer(account, shares);

        //  add deposited dai to userDaiDeposits mapping
        userDAIdeposits[account] = userDAIdeposits[account].add(amount);
    }
    
    function _withdrawBySharesOnly(address owner, uint256 balanceShares) internal {

        //  We now call the withdraw function to withdraw the total DAi we have. This withdrawal is sent to this smart contract
        _vBUSD.redeem(balanceShares);

        uint256 contractDaiBalance = _BUSD.balanceOf(address(this));

        //  Now all the DAI we have are in the smart contract wallet, we can now transfer the total amount to the recipient
        _BUSD.safeTransfer(owner, contractDaiBalance);

        //   remove withdrawn dai of this owner from userDaiDeposits mapping
        if (userDAIdeposits[owner] >= contractDaiBalance) {
            userDAIdeposits[owner] = userDAIdeposits[owner].sub(
                contractDaiBalance
            );
        } else {
            userDAIdeposits[owner] = 0;
        }
    }
    
    function _withdrawBySharesAndAmount(address owner, uint256 balanceShares, uint256 amount) internal {
        
        //  We now call the withdraw function to withdraw the total DAi we have. This withdrawal is sent to this smart contract
        _vBUSD.redeem(balanceShares);

        //  Now all the DAi we have are in the smart contract wallet, we can now transfer the specified amount to a recipient of our choice
        _BUSD.safeTransfer(owner, amount);
        

        //   remove withdrawn DAi of this owner from userDaiDeposits mapping
        if (userDAIdeposits[owner] >= amount) {
            userDAIdeposits[owner] = userDAIdeposits[owner].sub(
                amount
            );
        } else {
            userDAIdeposits[owner] = 0;
        }
    }
}