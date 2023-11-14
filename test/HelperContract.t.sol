//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/JokerToken.sol";

abstract contract HelperContract {
    address public treasury = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public protocolFeeDestination = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address public subject = 0x000000000000000000000000000000000000dEaD;
    address public subjectOwner = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address public defaultSender = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    address public defaultTxOrigin = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    uint256 public seed = 0x123456789;
    string public name = "Death Address";
    string public symbol = "DAT";
    uint112 public maxSupply = 2100 * (10 ** 8);
    uint256 public halfMaxPrice = 1 * (10 ** 8);
    uint112 public midwaySupply = 100 * (10 ** 8);
}
