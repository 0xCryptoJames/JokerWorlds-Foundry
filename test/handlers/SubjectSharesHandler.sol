//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/JokerToken.sol";
import "../../src/SubjectSharesV1.sol";
import "../../src/SubjectsRegistryV1.sol";

contract SubjectSharesHandler is Test {
    JokerToken private jokerToken;
    SubjectSharesV1 private subjectShares;
    uint256 public jokerBalance;

    constructor(JokerToken _jokerToken, SubjectSharesV1 _subjectShares, uint256 _initialJokerBalance) {
        jokerToken = _jokerToken;
        subjectShares = _subjectShares;
        jokerBalance = _initialJokerBalance;
    }

    function buyShares(uint112 amount, uint256 payment) external {
        uint112 currentSupply = uint112(subjectShares.totalSupply());
        uint256 paymentAmount =
            subjectShares.getReserve(currentSupply + amount) - subjectShares.getReserve(currentSupply);
        (uint256 protocolFee1, uint256 subjectFee1) = subjectShares.getFees(paymentAmount);
        uint256 min = (paymentAmount + protocolFee1 + subjectFee1) / (10 ** 8);
        uint256 max = jokerToken.balanceOf(address(this));
        payment = bound(payment, min, max);
        jokerBalance += (payment - protocolFee1 - subjectFee1);
        subjectShares.buyShares(amount);
    }

    function sellShares(uint112 amount) external {
        uint256 max = subjectShares.balanceOf(address(this));
        amount = uint112(bound(amount, 0, max));
        uint112 currentSupply = uint112(subjectShares.totalSupply());
        uint256 currentReserve = jokerToken.balanceOf(address(subjectShares)); // gas saving
        uint256 reserve0 = subjectShares.getReserve(currentSupply);
        uint256 paymentAmount0 =
            subjectShares.getReserve(currentSupply) - subjectShares.getReserve(currentSupply - amount);
        uint256 profitToShare = currentReserve > reserve0 ? (currentReserve - reserve0) : 0; //The total incomes distributed by the application linked to this pool
        uint256 paymentAmount1 = paymentAmount0 * profitToShare / reserve0 + paymentAmount0;
        jokerBalance -= paymentAmount1;
        subjectShares.sellShares(amount);
    }
}
