// SPDX-LICENSE-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenPool} from "@ccip/contracts/src/v0.8/TokenPool.sol";
import {POOL} from "@ccip/contracts/src/v0.8/TokenPool.sol";

contract RebaseTokenPool is TokenPool {
    constructor{IERC20 _token, address[] memory _allowlist, address _rnmProxy, address _router} TokenPool(_token, 18,_allowlist,_rnmProxy, _router ){}


    function lockOrburn{}
}