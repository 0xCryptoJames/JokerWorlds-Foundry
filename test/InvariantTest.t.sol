//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/JokerToken.sol";
import "../src/SubjectSharesV1.sol";
import "../src/SubjectsRegistryV1.sol";
import "./HelperContract.t.sol";
import "./handlers/JokerTokenTradeHandler.sol";
import "./handlers/SubjectSharesHandler.sol";

contract InvariantTest is Test, HelperContract {
    JokerToken public jokerToken;
    JokerTokenTradeHandler public handlerOfJokerToken;
    SubjectsRegistryV1 public subjectsRegistry;
    SubjectSharesV1 public subjectShares;
    SubjectSharesHandler subjectSharesHandler;

    function setUp() external {
        jokerToken = new JokerToken{value: 0.005 ether}(treasury, protocolFeeDestination);
        handlerOfJokerToken = new JokerTokenTradeHandler(jokerToken, 0.005 ether);
        vm.deal(address(handlerOfJokerToken), 10000 ether);
        targetContract(address(handlerOfJokerToken));

        subjectsRegistry = new SubjectsRegistryV1(jokerToken, protocolFeeDestination);

        vm.startPrank(treasury);
        vm.deal(treasury, 10 ether);
        jokerToken.transfer(subjectOwner, 2500000 * (10 ** 8));
        vm.stopPrank();

        bytes32 _salt = bytes32(uint256(keccak256(abi.encodePacked(block.chainid, subject, seed, name, symbol))));
        address computedSharePool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(subjectsRegistry),
                            _salt,
                            keccak256(
                                abi.encodePacked(
                                    type(SubjectSharesV1).creationCode,
                                    abi.encode(
                                        jokerToken, subjectOwner, name, symbol, maxSupply, halfMaxPrice, midwaySupply
                                    )
                                )
                            )
                        )
                    )
                )
            )
        );

        vm.startPrank(subjectOwner);
        jokerToken.approve(computedSharePool, type(uint112).max);
        vm.stopPrank();

        address _subjectShares = subjectsRegistry.addToRegistry(
            subject, subjectOwner, seed, name, symbol, maxSupply, halfMaxPrice, midwaySupply
        );
        subjectShares = SubjectSharesV1(payable(_subjectShares));

        subjectSharesHandler = new SubjectSharesHandler(jokerToken, subjectShares, halfMaxPrice/ (10 ** 8));

        vm.deal(address(subjectSharesHandler), 4900000 ether);

        vm.startPrank(treasury);
        jokerToken.transfer(subjectOwner, 2400000 * (10 ** 8));
        vm.stopPrank();

        targetContract(address(subjectSharesHandler));
        excludeContract(address(subjectsRegistry));
    }

    function invariant_alwaysHaveEnoughEtherReserve() external view {
        console2.log("Balance of Ether:", address(jokerToken).balance);
        assert((address(jokerToken).balance) == handlerOfJokerToken.etherBalance());
    }

    function invariant_alwaysHaveEnoughJokerReserve() external view {
        console2.log("Balance of Joker Token:", jokerToken.balanceOf(address(subjectShares)));
        assert(jokerToken.balanceOf(address(subjectShares)) == subjectSharesHandler.jokerBalance());
    }
}
