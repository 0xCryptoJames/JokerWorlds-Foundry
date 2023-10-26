//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {JokerToken} from "../src/JokerToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract JokerTokenTest is Test {
    JokerToken public jokerToken;
    address public treasury;
    address public protocolFeeDestination;
    uint256 public initialPayment;

    function setUp() public {
        treasury = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        protocolFeeDestination = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        initialPayment = 0.005 ether;
        jokerToken = new JokerToken{value: initialPayment}(treasury, protocolFeeDestination);
    }

    function testPremintForReserve() public {
        assertEq(jokerToken.balanceOf(treasury), 5000000 * (10 ** 18));
    }

    function testOwnerOfContract() public {
        assertEq(jokerToken.owner(), address(this));
    }

    function testInitialPayment() public {
        vm.expectRevert(abi.encodeWithSignature("InsufficientPayment()"));
        JokerToken _jokerToken = new JokerToken{value: 0.004 ether}(treasury, protocolFeeDestination);
    }

    function testSetFeeDestinationOnlyAllowOwner(address _caller, address _testAddress) public {
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", _caller));
        jokerToken.setFeeDestination(_testAddress);
    }

    function testSetTreasurylyAllowOwner(address _caller, address _testAddress) public {
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", _caller));
        jokerToken.setTreasury(_testAddress);
    }

    function testSetProtocolFeePercentOnlyAllowOwner(address _caller, uint16 _feePercent) public {
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", _caller));
        jokerToken.setProtocolFeePercent(_feePercent);
    }

    function testBlacklistOnlyAllowOwner(address _caller, address user, bool _isBlacklisted) public {
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", _caller));
        jokerToken.blacklist(user, _isBlacklisted);
    }

    function testSetTransferEnabledOnlyAllowOwner(address _caller, bool _isEnabled) public {
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", _caller));
        jokerToken.setTransferEnabled(_isEnabled);
    }
}
