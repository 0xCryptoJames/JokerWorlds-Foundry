//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/JokerToken.sol";
import "./HelperContract.t.sol";

contract JokerTokenTest is Test, HelperContract {
    error PaymentFailed();
    error InvalidInputs();
    error InsufficientBalance();
    error TransferDisabled();
    error AddressBlacklisted();

    JokerToken public jokerToken;

    event Blacklist(address indexed tokenContract, address indexed evilAddress, bool isBlacklisted);

    event JokerTokenTrade(
        address indexed tokenContract, address indexed trader, bool isBuy, uint256 amount, uint256 payment
    );

    function setUp() external {
        vm.deal(address(this), 100 ether);
        jokerToken = new JokerToken{value: 0.005 ether}(treasury, protocolFeeDestination);
    }

    function testContractDeployment(
        address caller,
        uint256 initialPayment,
        address treasuryForTest,
        address protocolFeeDestinationForTest
    ) external {
        vm.assume(caller != address(0) && initialPayment < 90 ether);
        vm.startPrank(caller);
        vm.deal(caller, 100 ether);
        if (
            initialPayment < 0.005 ether || treasuryForTest == address(0) || protocolFeeDestinationForTest == address(0)
        ) {
            vm.expectRevert(abi.encodeWithSignature("InvalidInputs()"));
            JokerToken jokerToken0 =
                new JokerToken{value: initialPayment}(treasuryForTest, protocolFeeDestinationForTest);
        } else {
            JokerToken jokerToken1 =
                new JokerToken{value: initialPayment}(treasuryForTest, protocolFeeDestinationForTest);
            assert(jokerToken1.balanceOf(treasuryForTest) == 5000000 * (10 ** 8));
            assert(jokerToken1.owner() == caller);
        }
        vm.stopPrank();
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
        vm.assume(caller != address(0) && caller != jokerToken.owner());
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

        vm.expectEmit(true, true, false, true, address(jokerToken));
        emit Blacklist(address(jokerToken), evil, isBlacklisted);
        jokerToken.blacklist(evil, isBlacklisted);
        assert(jokerToken.blacklisted(evil) == isBlacklisted);

        jokerToken.setTransferEnabled(isEnabled);
        assert(jokerToken.isTransferEnabled() == isEnabled);
    }

    function testBuyTokens(address caller, uint112 amount, uint256 paymentAmount) external {
        vm.assume(caller != address(0) && paymentAmount < 900 ether);
        vm.startPrank(caller);
        vm.deal(caller, 1000 ether);
        if (amount == 0 || (jokerToken.totalSupply() + amount > type(uint112).max)) {
            vm.expectRevert(abi.encodeWithSignature("InvalidInputs()"));
            jokerToken.buyTokens{value: paymentAmount}(amount);
        } else {
            uint112 currentReserve0 = uint112(jokerToken.totalSupply());
            uint256 paymentAmount0 =
                jokerToken.getReserve(currentReserve0 + amount) - jokerToken.getReserve(currentReserve0);
            uint256 protocolFee = paymentAmount0 * jokerToken.protocolFeePercent() / 10000;
            if (paymentAmount < paymentAmount0 + protocolFee) {
                vm.expectRevert(abi.encodeWithSignature("InsufficientBalance()"));
                jokerToken.buyTokens{value: paymentAmount}(amount);
            } else {
                uint256 balanceBefore0 = jokerToken.balanceOf(caller);
                vm.expectEmit(true, true, true, true, address(jokerToken));
                emit JokerTokenTrade(address(jokerToken), caller, true, amount, paymentAmount);
                jokerToken.buyTokens{value: paymentAmount}(amount);
                uint256 balanceAfter0 = jokerToken.balanceOf(caller);

                assert(uint112(balanceAfter0 - balanceBefore0) == amount);
            }
        }
        vm.stopPrank();
    }

    function testSellTokens(address caller, uint112 amount) external {
        vm.assume(caller != address(0));
        vm.startPrank(caller);
        vm.deal(caller, 10 ether);
        if (amount == 0) {
            vm.expectRevert(abi.encodeWithSignature("InvalidInputs()"));
            jokerToken.sellTokens(amount);
        } else {
            if (amount > jokerToken.balanceOf(caller)) {
                vm.expectRevert(abi.encodeWithSignature("InsufficientBalance()"));
                jokerToken.sellTokens(amount);
            } else {
                uint256 balanceBefore0 = jokerToken.balanceOf(caller);
                uint256 balanceBefore1 = address(jokerToken).balance;
                uint112 currentReserve1 = uint112(jokerToken.totalSupply());
                uint256 paymentAmount =
                    jokerToken.getReserve(currentReserve1) - jokerToken.getReserve(currentReserve1 - amount);
                vm.expectEmit(true, true, true, true, address(jokerToken));
                emit JokerTokenTrade(address(jokerToken), caller, false, amount, paymentAmount);
                jokerToken.sellTokens(amount);
                uint256 balanceAfter0 = jokerToken.balanceOf(caller);
                uint256 balanceAfter1 = address(jokerToken).balance;

                assert(uint112(balanceBefore0 - balanceAfter0) == amount);
                assert(balanceBefore1 - balanceAfter1 == paymentAmount);
            }
        }
        vm.stopPrank();
    }
}
