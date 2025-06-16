// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/*
* @title Rebase Token
* @author Aryan
* @notice This is a cross-chain rebase token that incentivizes users to dposit into a vault
* @notice The intraest rate decreases ovretime, and each user will have a unique Intrest rate
*/

contract RebaseToken is ERC20, Ownable, AccessControl {

    error RebaseToken__IntrestRateCanOnlyDecrease(uint256 oldIntrestRate, uint256 newIntrestRate);

    uint256 private s_intrestRate = 5e10;
    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    mapping(address => uint256) private s_userIntrestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event IntrestRateSet(uint256 newIntrestRate);

    constructor() ERC20("Rebase Token","RBT" ) Ownable(msg.sender){}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    function setIntrestRate(uint256 _newIntrestRate) external onlyOwner { 
        if (_newIntrestRate > s_intrestRate){
            revert RebaseToken__IntrestRateCanOnlyDecrease(s_intrestRate, _newIntrestRate);
        }
        s_intrestRate = _newIntrestRate;
        emit IntrestRateSet(_newIntrestRate);

    }

    function mint(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccuredIntrest(_from);
        s_userIntrestRate[_from] = s_intrestRate;
        _mint(_from, _amount);


    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if(_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccuredIntrest(_from);
        s_userIntrestRate[_from] = s_intrestRate;
        _burn(_from, _amount);
    }

    function _mintAccuredIntrest(address _user) internal {
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipalBalance;
        //Balance of the minted tokens: principal
        //Balance of the minted tokens plus intrest
        //no of tokens to be mintted for paying their intrest
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, balanceIncrease);
    }


    function getIntrestRate() external view returns (uint256) {
        return s_intrestRate;
    }

    function balanceOf(address _user) public view override returns (uint256) {
        uint256 currentPrincipalBalance = super.balanceOf(_user);
        if (currentPrincipalBalance == 0) {
            return 0;
        }
        return (currentPrincipalBalance * _calculateUserAccumulatedIntrestSinceLastUpdate(_user)) / PRECISION_FACTOR;
    }

    function transfer( address _recipient, uint256 _amount) public override returns (bool){
        _mintAccuredIntrest(msg.sender);
        _mintAccuredIntrest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0){
            s_userIntrestRate[_recipient] = s_userIntrestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccuredIntrest(_sender);
        _mintAccuredIntrest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0){
            s_userIntrestRate[_recipient] = s_userIntrestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    function _calculateUserAccumulatedIntrestSinceLastUpdate(address _user) internal view returns (uint256 linearIntrest) {
        //Intrest grows linearly over time
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearIntrest = PRECISION_FACTOR + (s_userIntrestRate[_user] * timeElapsed);
    }

    function principalBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    function getUserIntrestRate(address _user) external view returns (uint256) {
        return s_userIntrestRate[_user];
    }
}