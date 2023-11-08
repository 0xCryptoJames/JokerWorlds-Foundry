//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {JokerToken} from "../../src/JokerToken.sol";

contract JokerTokenTradeHandler is Test {
    JokerToken jokerToken;

    constructor(JokerToken _jokerToken) {
        jokerToken = _jokerToken;
        vm.deal(address(this), 1000 ether);
    }

    function buyTokens(uint112 amount) external payable {
        jokerToken.buyTokens(amount);
    }

    function sellTokens(uint112 amount) external {
        jokerToken.sellTokens(amount);
    }
}
