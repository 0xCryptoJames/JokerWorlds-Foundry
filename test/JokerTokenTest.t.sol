//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {JokerToken} from "../src/JokerToken.sol";
import {HelperContract} from "./HelperContract.t.sol";
import {console} from "forge-std/console.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract JokerTokenTest is Test, HelperContract {
    JokerToken public jokerToken;

    function setUp() external {
        vm.deal(address(this), 100 ether);
        jokerToken = new JokerToken{value: 0.005 ether}(treasury, protocolFeeDestination);
    }

    function testPremintForReserve() external {
        assertEq(jokerToken.balanceOf(treasury), 5000000 * (10 ** 18));
    }

    function testOwnerOfContract() external {
        assertEq(jokerToken.owner(), address(this));
    }

    function testInitialPayment(uint256 initialPayment, bytes32 salt1) external {
        vm.assume(initialPayment < 0.005 ether);
        vm.expectRevert(abi.encodeWithSignature("InsufficientPayment()"));
        JokerToken _jokerToken = new JokerToken{salt: salt1, value: 0.004 ether}(treasury, protocolFeeDestination);
    }

    function testSetFeeDestinationOnlyAllowOwner(address caller, address testAddress) external {
        vm.assume(caller != address(this));
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        jokerToken.setFeeDestination(testAddress);
    }

    function testSetTreasurylyAllowOwner(address caller, address testAddress) external {
        vm.assume(caller != address(this));
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        jokerToken.setTreasury(testAddress);
    }

    function testSetProtocolFeePercentOnlyAllowOwner(address caller, uint16 feePercent) external {
        vm.assume(feePercent < 10000);
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        jokerToken.setProtocolFeePercent(feePercent);
    }

    function testBlacklistOnlyAllowOwner(address caller, address evil, bool isBlacklisted) external {
        vm.assume(caller != address(this));
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        jokerToken.blacklist(evil, isBlacklisted);
    }

    function testSetTransferEnabledOnlyAllowOwner(address caller, bool isEnabled) external {
        vm.assume(caller != address(this));
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        jokerToken.setTransferEnabled(isEnabled);
    }
}
