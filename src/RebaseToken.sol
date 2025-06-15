// SPDX-License-Identifier: MIT
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
    uint256 private constant PRECISION_FATCOR = 1e18;
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

    function mint(address _from, uint256 _amount) external {
        _mintAccuredInterest(_from);
        s_userInterestRate[_from] = s_intrestRate;
        _mint(_from, _amount);


    }

    function burn(address _from, uint256 _amount) external {
        _mintAccuredInterest(_from);
        s_userInterestRate[_from] = s_intrestRate;
        _burn(_from, _amount);
    }

    function _mintAccuredIntrest(address _to) internal {
        uint256 previousPrincipalBalance = super.balanceOf(_to);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipalBalance;
        //Balance of the minted tokens: principal
        //Balance of the minted tokens plus intrest
        //no of tokens to be mintted for paying their intrest
        s_userLastUpdatedTimestamp[_to] = block.timestamp;
        _mint(_user, balanceIncrease);
    }


    function getIntrestRate() external view returns (uint256) {
        return s_intrestRate;
    }

    function balanceOf(address account) public view override returns (uint256) {
        uint256 currentPrincipalBalance = super.balanceOf(account);
        if (currentPrincipalBalance == 0) {
            return 0;
        }
        return (currentPrincipalBalance * _calculateUserAccumulatedIntrestSinceLastUpdate(_user)) / PRECISION_FACTOR;
    }

    function _calculateUserAccumulatedIntrestSinceLastUpdate(address _user) internal view returns (linearIntrest) {
        //Intrest grows linearly over time
        uint256 timeElaped = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearIntrest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

}