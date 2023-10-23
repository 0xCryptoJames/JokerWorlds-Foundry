//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ISubjectsRegistryV1 {
    function protocolFeeDestination() external view returns(address);
    function bondingPair(address) external view returns(address);
    function protocolFeeRates(address) external view returns(uint16);
    function isBlacklisted(address) external view returns(bool);
}