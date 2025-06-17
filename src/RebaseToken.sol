// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/** 
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


    /**
    * @notice Grants the MINT_AND_BURN_ROLE to an account, can only be called by the owner
    * @param _account The address to grant the role to
    */
    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
    * @notice sets the interest rate for the token, can only be called by the owner
    * @param _newIntrestRate The new interest rate to set
    * @dev The interest rate can only decrease, if the new interest rate is greater than or equal to the current interest rate, it will revert
    */
    function setIntrestRate(uint256 _newIntrestRate) external onlyOwner { 
        if (_newIntrestRate >= s_intrestRate){
            revert RebaseToken__IntrestRateCanOnlyDecrease(s_intrestRate, _newIntrestRate);
        }
        s_intrestRate = _newIntrestRate;
        emit IntrestRateSet(_newIntrestRate);

    }

    /**
    * @notice Mints tokens to the specified address and updates the interest rate for that user, can only be called by the MINT_AND_BURN_ROLE
    * @param _to The address to mint tokens to
    * @param _amount The amount of tokens to mint
    */

    function mint(address _to, uint256 _amount,uint256 _userIntrestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccuredIntrest(_to);
        s_userIntrestRate[_to] = _userIntrestRate;
        _mint(_to, _amount);
    }

    /**
    * @notice Burns tokens from the specified address, and mints accrued interest for that user, can only be called by the MINT_AND_BURN_ROLE
    * @param _from The address to burn tokens from
    */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if(_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccuredIntrest(_from);
        s_userIntrestRate[_from] = s_intrestRate;
        _burn(_from, _amount);
    }

    /**
    * @notice Mints accrued interest for the user and adds them to the principal balance, this function is called before every transfer and transferFrom
    * @param _user The address of the user to mint accrued interest for
    */
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

    /**
    * @notice Returns the current interest rate for the token
    */
    function getIntrestRate() external view returns (uint256) {
        return s_intrestRate;
    }

    /**
    * @notice Returns the balance of the user, including accrued interest
    * @param _user The address of the user to check the balance of
    */
    function balanceOf(address _user) public view override returns (uint256) {
        uint256 currentPrincipalBalance = super.balanceOf(_user);
        if (currentPrincipalBalance == 0) {
            return 0;
        }
        return (currentPrincipalBalance * _calculateUserAccumulatedIntrestSinceLastUpdate(_user)) / PRECISION_FACTOR;
    }

    /**
    * @notice Transfers tokens to the specified recipient and mints accrued interest for both the sender and recipient
    * @param _recipient The address to transfer tokens to
    * @param _amount The amount of tokens to transfer, if the amount is type(uint
    */
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

    /**
    * @notice Transfers tokens from the specified sender to the recipient and mints accrued interest for both the sender and recipient
    * @param _sender The address to transfer tokens from
    * @param _recipient The address to transfer tokens to
    * @param _amount The amount of tokens to transfer, if the amount is type(uint
    */
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

    /**
    * @notice Calculates the accumulated interest for a user since their last update
    * @param _user The address of the user to calculate the accumulated interest for
    * @return linearIntrest The accumulated interest for the user
    */    
    function _calculateUserAccumulatedIntrestSinceLastUpdate(address _user) internal view returns (uint256 linearIntrest) {
        //Intrest grows linearly over time
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearIntrest = PRECISION_FACTOR + (s_userIntrestRate[_user] * timeElapsed);
    }

    /**
    * @notice Returns the principal balance of the user, which is the balance without accrued interest
    * @param _user The address of the user to check the principal balance of
    * @return The principal balance of the user
    */
    function principalBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
    * @notice Returns the interest rate for a specific user
    * @param _user The address of the user to check the interest rate for
    */
    function getUserIntrestRate(address _user) external view returns (uint256) {
        return s_userIntrestRate[_user];
    }
}