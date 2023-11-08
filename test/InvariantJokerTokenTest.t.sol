//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {JokerToken} from "../src/JokerToken.sol";
import {HelperContract} from "./HelperContract.t.sol";
import {JokerTokenTradeHandler} from "./handlers/JokerTokenTradeHandler.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract InvariantJokerTokenTest is Test, HelperContract {
    JokerToken jokerToken;
    JokerTokenTradeHandler handlerOfJokerToken;

    function setUp() external {
        vm.deal(address(this), 100 ether);
        jokerToken = new JokerToken{value: 0.005 ether}(treasury, protocolFeeDestination);
        handlerOfJokerToken = new JokerTokenTradeHandler(jokerToken);
        targetContract(address(handlerOfJokerToken));
    }

    function invariant_alwaysHaveEnoughEtherReserve() external view {
        uint112 supply = uint112(jokerToken.totalSupply());
        uint112 supplyDiff = supply < jokerToken.MIDWAY_SUPPLY()
            ? (jokerToken.MIDWAY_SUPPLY() - supply)
            : (supply - jokerToken.MIDWAY_SUPPLY());
        uint256 reserve;
        if (supply < jokerToken.MIDWAY_SUPPLY()) {
            reserve = jokerToken.HALF_MAXPRICE() * (Math.sqrt(1 + (uint256(supplyDiff) ** 2)) - uint256(supplyDiff));
        } else {
            reserve = jokerToken.HALF_MAXPRICE() * (Math.sqrt(1 + (uint256(supplyDiff) ** 2)) + uint256(supplyDiff));
        }

        assert(address(jokerToken).balance >= reserve);
    }
}
