//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/JokerToken.sol";

contract JokerTokenTradeHandler is Test {
    JokerToken private jokerToken;
    uint256 public etherBalance;

    constructor(JokerToken _jokerToken, uint256 _initialPayment) {
        jokerToken = _jokerToken;
        etherBalance = _initialPayment;
    }

    function buyTokens(uint112 amount, uint256 payment) external payable {
        uint112 currentReserve0 = uint112(jokerToken.totalSupply());
        uint256 paymentAmount0 =
            jokerToken.getReserve(currentReserve0 + amount) - jokerToken.getReserve(currentReserve0);
        uint256 protocolFee = paymentAmount0 * jokerToken.protocolFeePercent() / 10000;
        uint256 min = (paymentAmount0 + protocolFee) / (10 ** 8);
        uint256 max = address(this).balance;
        payment = bound(payment, min, max);

        etherBalance += (payment - protocolFee / (10 ** 8));

        jokerToken.buyTokens{value: payment}(amount);
    }

    function sellTokens(uint112 amount) external {
        uint256 max = uint256(jokerToken.balanceOf(address(this)));
        amount = uint112(bound(amount, 0, max));
        uint112 currentReserve1 = uint112(jokerToken.totalSupply());
        uint256 paymentAmount = jokerToken.getReserve(currentReserve1) - jokerToken.getReserve(currentReserve1 - amount);
        etherBalance -= (paymentAmount / (10 ** 8));
        jokerToken.sellTokens(amount);
    }
}
