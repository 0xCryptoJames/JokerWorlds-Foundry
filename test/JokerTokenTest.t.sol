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

    function testContractDeployment(
        uint256 initialPayment,
        address treasuryForTest,
        address protocolFeeDestinationForTest
    ) external {
        vm.assume(initialPayment < 10 ether);
        vm.deal(address(this), 1000 ether);
        if (initialPayment < 0.005 ether) {
            if (treasuryForTest == address(0) || protocolFeeDestinationForTest == address(0)) {
                vm.expectRevert(abi.encodeWithSignature("InvalidInputs()"));
                JokerToken jokerToken0 =
                    new JokerToken{value: initialPayment}(treasuryForTest, protocolFeeDestinationForTest);
            }
            vm.expectRevert(abi.encodeWithSignature("InsufficientPayment()"));
            JokerToken jokerToken1 =
                new JokerToken{value: initialPayment}(treasuryForTest, protocolFeeDestinationForTest);
        }

        if (
            (initialPayment >= 0.005 ether)
                && (treasuryForTest == address(0) || protocolFeeDestinationForTest == address(0))
        ) {
            vm.expectRevert(abi.encodeWithSignature("InvalidInputs()"));
            JokerToken jokerToken2 =
                new JokerToken{value: initialPayment}(treasuryForTest, protocolFeeDestinationForTest);
        }

        if (
            initialPayment >= 0.005 ether && treasuryForTest != address(0)
                && protocolFeeDestinationForTest != address(0)
        ) {
            JokerToken jokerToken3 =
                new JokerToken{value: initialPayment}(treasuryForTest, protocolFeeDestinationForTest);
            assert(jokerToken3.balanceOf(treasuryForTest) == 5000000 * (10 ** 18));
            assert(jokerToken3.owner() == address(this));
        }
    }

    function testOnlyOwnerAllowedFunctions(
        address caller,
        address testFeeDestinationAddress,
        address testTreasuryAddress,
        uint16 newFeePercent,
        address evil,
        bool isBlacklisted,
        bool isEnabled
    ) external {
        vm.startPrank(caller);
        vm.deal(caller, 10 ether);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        jokerToken.setFeeDestination(testFeeDestinationAddress);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        jokerToken.setTreasury(testTreasuryAddress);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        jokerToken.setProtocolFeePercent(newFeePercent);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        jokerToken.blacklist(evil, isBlacklisted);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        jokerToken.setTransferEnabled(isEnabled);
        vm.stopPrank();

        if (testFeeDestinationAddress == address(0)) {
            vm.expectRevert(abi.encodeWithSignature("InvalidInputs()"));
            jokerToken.setFeeDestination(testFeeDestinationAddress);
        } else {
            jokerToken.setFeeDestination(testFeeDestinationAddress);
            assert(jokerToken.protocolFeeDestination() == testFeeDestinationAddress);
        }

        if (testTreasuryAddress == address(0)) {
            vm.expectRevert(abi.encodeWithSignature("InvalidInputs()"));
            jokerToken.setTreasury(testTreasuryAddress);
        } else {
            jokerToken.setTreasury(testTreasuryAddress);
            assert(jokerToken.treasury() == testTreasuryAddress);
        }

        if (newFeePercent >= 10000) {
            vm.expectRevert(abi.encodeWithSignature("InvalidInputs()"));
            jokerToken.setProtocolFeePercent(newFeePercent);
        } else {
            jokerToken.setProtocolFeePercent(newFeePercent);
            assert(jokerToken.protocolFeePercent() == newFeePercent);
        }

        jokerToken.blacklist(evil, isBlacklisted);
        assert(jokerToken.blacklisted(evil) == isBlacklisted);

        jokerToken.setTransferEnabled(isEnabled);
        assert(jokerToken.isTransferEnabled() == isEnabled);
    }
}
