// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IRebaseToken } from "./interfaces/IRebaseToken.sol";

contract Vault {


    IRebaseToken private immutable i_rebaseToken;

    error Vault__RedeemFailed();

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    function deposit() external payable {
        i_rebaseToken.mint(msg.sender,msg.value, i_rebaseToken.getUserInterestRate(msg.sender));
        emit Deposit(msg.sender, msg.value);        
    }

   function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        i_rebaseToken.burn(msg.sender, _amount);
        // executes redeem of the underlying asset
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    function getRebaseToken() external view returns (address) {
        return address (i_rebaseToken);
    }
} 