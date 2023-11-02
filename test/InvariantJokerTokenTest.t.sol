//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {JokerToken} from "../src/JokerToken.sol";
import {HelperContract} from "./HelperContract.t.sol";
import {console} from "forge-std/console.sol";
import {OpenTest} from "./handlers/OpenTest.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InvariantJokerTokenTest is Test, HelperContract {
    JokerToken jokerToken;
    OpenTest handlerOfOpenTest;

    function setUp() external {
        vm.deal(address(this), 100 ether);
        jokerToken = new JokerToken{value: 0.005 ether}(treasury, protocolFeeDestination);
        handlerOfOpenTest = new OpenTest(jokerToken);
        targetContract(address(handlerOfOpenTest));
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
