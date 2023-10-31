//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {JokerToken} from "../src/JokerToken.sol";
import {HelperContract} from "./HelperContract.t.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract JokerTokenTest is Test, HelperContract {
    JokerToken public jokerToken;

    function setUp() public {
        jokerToken = new JokerToken{value: 0.005 ether}(treasury, protocolFeeDestination);
    }

    function testPremintForReserve() public {
        assertEq(jokerToken.balanceOf(treasury), 5000000 * (10 ** 18));
    }

    function testOwnerOfContract() public {
        assertEq(jokerToken.owner(), address(this));
    }

    function testInitialPayment(uint256 initialPayment, bytes32 salt1) public {
        vm.assume(initialPayment < 0.005 ether);
        vm.expectRevert(abi.encodeWithSignature("InsufficientPayment()"));
        JokerToken _jokerToken = new JokerToken{salt: salt1, value: 0.004 ether}(treasury, protocolFeeDestination);
    }

    function testSetFeeDestinationOnlyAllowOwner(address caller, address testAddress) public {
        vm.assume(caller != address(this));
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        jokerToken.setFeeDestination(testAddress);
    }

    function testSetTreasurylyAllowOwner(address caller, address testAddress) public {
        vm.assume(caller != address(this));
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        jokerToken.setTreasury(testAddress);
    }

    function testSetProtocolFeePercentOnlyAllowOwner(address caller, uint16 feePercent) public {
        vm.assume(caller != address(this));
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        jokerToken.setProtocolFeePercent(feePercent);
    }

    function testBlacklistOnlyAllowOwner(address caller, address evil, bool isBlacklisted) public {
        vm.assume(caller != address(this));
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        jokerToken.blacklist(evil, isBlacklisted);
    }

    function testSetTransferEnabledOnlyAllowOwner(address caller, bool isEnabled) public {
        vm.assume(caller != address(this));
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        jokerToken.setTransferEnabled(isEnabled);
    }

    function invariant_A() public {
        vm.prank(user);
        uint256 calculatedTotalReserve = jokerToken.HALF_MAXPRICE()
            * (
                Math.sqrt(1 + (jokerToken.totalSupply() - jokerToken.MIDWAY_SUPPLY()) ** 2)
                    + (jokerToken.totalSupply() - jokerToken.MIDWAY_SUPPLY())
            );
        assertGe(address(jokerToken).balance, calculatedTotalReserve);
    }
}
