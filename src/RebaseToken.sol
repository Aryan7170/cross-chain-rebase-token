//SPDX-LICENSE-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*
* @title Rebase Token
* @author Aryan
* @notice This is a cross-chain rebase token that incentivizes users to dposit into a vault
* @notice The intraest rate decreases ovretime, and each user will have a unique interest rate
*/

contract RebaseToken is ERC20 {

    error RebaseToken__IntrestRateCanOnlyDecrease(uint256 oldIntrestRate, uint256 newIntrestRate);

    uint256 private s_intrestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event IntrestRateSet(uint256 newIntrestRate);

    constructor() ERC20("Rebase Token","RBT" ){}

    function setIntrestRate(uint256 _newIntrestRate) external { 
        if (_newIntrestRate > s_intrestRate){
            revert RebaseToken__IntrestRateCanOnlyDecrease(s_intrestRate, _newIntrestRate);
        }
        s_intrestRate = _newIntrestRate;
        emit IntrestRateSet(_newIntrestRate);

    }

    function mint(address _to, uint256 _amount) external {
        _mintAccuredInterest(_to);
        s_userInterestRate[_to] = s_intrestRate;
        _mint(_to, _amount);


    }

    function _mintAccuredIntrest(address _to) internal {
        //Balance of the minted tokens: principal
        //Balance of the minted tokens plus intrest
        //no of tokens to be mintted for paying their intrest
        s_userLastUpdatedTimestamp[_to] = block.timestamp;
    }


    function getIntrestRate() external view returns (uint256) {
        return s_intrestRate;
    }

    function balanceOf(address account) public view override returns (uint256){
        return super.balanceOf(account) * _calculateUserAccumulatedIntrestSinceLastUpdate(_user);
    }

}