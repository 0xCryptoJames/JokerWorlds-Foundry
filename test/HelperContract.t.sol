//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {JokerToken} from "../src/JokerToken.sol";

abstract contract HelperContract {
    address public treasury = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public protocolFeeDestination = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public user = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
}
