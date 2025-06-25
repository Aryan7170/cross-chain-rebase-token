// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/** 
* @title Rebase Token
* @author Aryan
* @notice This is a cross-chain rebase token that incentivizes users to dposit into a vault
* @notice The intraest rate decreases ovretime, and each user will have a unique Interest rate
*/

contract RebaseToken is ERC20, Ownable, AccessControl {


    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);


    uint256 private s_InterestRate = (5 * PRECISION_FACTOR) / 1e8;
    uint256 private constant PRECISION_FACTOR = 1e27;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;


    event InterestRateSet(uint256 newInterestRate);


    constructor() ERC20("Rebase Token","RBT" ) Ownable(msg.sender){}


    /**
    * @notice Grants the MINT_AND_BURN_ROLE to an account, can only be called by the owner
    * @param _account The address to grant the role to
    */
    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
    * @notice sets the Interest rate for the token, can only be called by the owner
    * @param _newInterestRate The new Interest rate to set
    * @dev The Interest rate can only decrease, if the new Interest rate is greater than or equal to the current Interest rate, it will revert
    */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner { 
        if (_newInterestRate >= s_InterestRate){
            revert RebaseToken__InterestRateCanOnlyDecrease(s_InterestRate, _newInterestRate);
        }
        s_InterestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);

    }

    /**
    * @notice Mints tokens to the specified address and updates the Interest rate for that user, can only be called by the MINT_AND_BURN_ROLE
    * @param _to The address to mint tokens to
    * @param _amount The amount of tokens to mint
    */

    function mint(address _to, uint256 _amount,uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccuredInterest(_to);
        s_userInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    /**
    * @notice Burns tokens from the specified address, and mints accrued Interest for that user, can only be called by the MINT_AND_BURN_ROLE
    * @param _from The address to burn tokens from
    */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if(_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccuredInterest(_from);
        s_userInterestRate[_from] = s_InterestRate;
        _burn(_from, _amount);
    }

    /**
    * @notice Mints accrued Interest for the user and adds them to the principal balance, this function is called before every transfer and transferFrom
    * @param _user The address of the user to mint accrued Interest for
    */
    function _mintAccuredInterest(address _user) internal {
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipalBalance;
        //Balance of the minted tokens: principal
        //Balance of the minted tokens plus Interest
        //no of tokens to be mintted for paying their Interest
        
        _mint(_user, balanceIncrease);
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
    }

    /**
    * @notice Returns the current Interest rate for the token
    */
    function getInterestRate() external view returns (uint256) {
        return s_InterestRate;
    }

    /**
    * @notice Returns the balance of the user, including accrued Interest
    * @param _user The address of the user to check the balance of
    */
    function balanceOf(address _user) public view override returns (uint256) {
        uint256 currentPrincipalBalance = super.balanceOf(_user);
        if (currentPrincipalBalance == 0) {
            return 0;
        }
        return (currentPrincipalBalance * _calculateUserAccumulatedInterestSinceLastUpdate(_user)) / PRECISION_FACTOR;
    }

    /**
    * @notice Transfers tokens to the specified recipient and mints accrued Interest for both the sender and recipient
    * @param _recipient The address to transfer tokens to
    * @param _amount The amount of tokens to transfer, if the amount is type(uint
    */
    function transfer( address _recipient, uint256 _amount) public override returns (bool){
        _mintAccuredInterest(msg.sender);
        _mintAccuredInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0){
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
    * @notice Transfers tokens from the specified sender to the recipient and mints accrued Interest for both the sender and recipient
    * @param _sender The address to transfer tokens from
    * @param _recipient The address to transfer tokens to
    * @param _amount The amount of tokens to transfer, if the amount is type(uint
    */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccuredInterest(_sender);
        _mintAccuredInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0){
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
    * @notice Calculates the accumulated Interest for a user since their last update
    * @param _user The address of the user to calculate the accumulated Interest for
    * @return linearInterest The accumulated Interest for the user
    */    
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns (uint256 linearInterest) {
        //Interest grows linearly over time
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    /**
    * @notice Returns the principal balance of the user, which is the balance without accrued Interest
    * @param _user The address of the user to check the principal balance of
    * @return The principal balance of the user
    */
    function principalBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
    * @notice Returns the Interest rate for a specific user
    * @param _user The address of the user to check the Interest rate for
    */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}