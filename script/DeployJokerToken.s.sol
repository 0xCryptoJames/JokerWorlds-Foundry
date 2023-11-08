//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {JokerToken} from "../src/JokerToken.sol";
import {HelperContract} from "../test/HelperContract.t.sol";

contract DeployJokerToken is Script, HelperContract {
    function run() external {
        vm.startBroadcast();
        JokerToken jokerToken = new JokerToken{value: 0.005 ether}(treasury, protocolFeeDestination);
        vm.stopBroadcast();
    }
}
