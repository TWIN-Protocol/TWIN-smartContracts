// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./interfaces/IDolomite.sol";
import "./interfaces/IDolomiteHelper.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// @ The yield farm for the TWIn Finance Protocol
contract Farm is ERC20 {
    ERC20 public usdcToken;
    IDolomite public dolomite;
    IDolomiteHelper public dolomiteHelper;
    address public yieldReceiver;
    address dolomiteMarginAddress;
    uint256 public marketId;

    constructor(address _usdcAddress, address _dolomiteAddress, address _dolomiteHelperAddress, address _dolomiteMarginAddress, address _yieldReceiver, uint256 _marketId) ERC20("twinUSDC Token", "twinUSDC") {
        usdcToken = ERC20(_usdcAddress);
        dolomite = IDolomite(_dolomiteAddress);
        yieldReceiver = _yieldReceiver;
        dolomiteHelper = IDolomiteHelper(_dolomiteHelperAddress);
        dolomiteMarginAddress = _dolomiteMarginAddress;
        marketId = _marketId;
    }

    // Override the decimals function to return 6
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    function changeYieldReceiver(address _newYieldReceiver) public {
        require(msg.sender == yieldReceiver, "Sender not yieldReciever");
        yieldReceiver = _newYieldReceiver;
    } 
    
    function supply(uint256 amount) external {
        require(usdcToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        require(usdcToken.approve(dolomiteMarginAddress, amount),"Error approving");
        dolomite.depositWeiIntoDefaultAccount(marketId, amount);
        _mint(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _burn(msg.sender, amount);
        dolomite.withdrawWeiFromDefaultAccount(marketId, amount,1);
        require(usdcToken.transfer(msg.sender, amount), "Transfer to user failed");
        
        harvestYield();
    }
    
    function harvestYield() public {
        uint256 totalSupply = totalSupply();
        uint256 totalShares = dolomiteHelper.balanceOf(address(this));
        uint256 farmBalance = dolomiteHelper.convertToAssets(totalShares);
        uint256 totalInterest = farmBalance - totalSupply;
        require(totalInterest >= 0, "Negative interest, should not happen");

        if (totalInterest > 0) {
            dolomite.withdrawWeiFromDefaultAccount(marketId, totalInterest,1);
            require(usdcToken.transfer(yieldReceiver, totalInterest), "Transfer to yield receiver failed");
        }
    }

    function showYield() public view returns (uint256){
        uint256 totalCurrentSupply = totalSupply();
        uint256 totalShares = dolomiteHelper.balanceOf(address(this));
        uint256 farmBalance = dolomiteHelper.convertToAssets(totalShares);
        uint256 totalInterest = farmBalance - totalCurrentSupply;
        return totalInterest;
    }      
    
    
}
