// SPDX-LICENSE-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {vault} from "../src/vault.sol";
import {CCIPLocalSimulatorFrok} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFrok.sol";

contract CrossChainTest is Test {
    uint256 sepoliaFrok;
    uint256 arbSepoliaFork;

    CCIPLocalSimulatorFork ccipLocalSimulatorFrok;
    
    function setup() public{
        sepoliaFrok = vm.createSelectFork("Sepolia");
        arbSepoliaFork = vm.createFork("arb-Sepolia");

        ccipLocalSimulatorFrok = new CCIPLocalSimulatorFork();
        ccip.makePersistant(address(ccipLocalSimulatorFork));
    }
}