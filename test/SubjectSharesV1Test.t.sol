//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SubjectSharesV1.sol";
import "../src/SubjectsRegistryV1.sol";
import "../src/JokerToken.sol";
import "./HelperContract.t.sol";

contract SubjectSharesV1Test is Test, HelperContract {
    error PaymentFailed();
    error InvalidInputs();
    error InsufficientBalance();
    error AddressBlacklisted();
    error Unauthorized();
    error PoolCreationFailed();
    error SubjectRegistered();
    error OwnableUnauthorizedAccount(address account);

    JokerToken public jokerToken;
    SubjectsRegistryV1 public subjectsRegistry;
    SubjectSharesV1 public subjectShares;

    function setUp() external {
        vm.deal(msg.sender, 10 ether);
        address sender = msg.sender;
        vm.startPrank(sender);
        jokerToken = new JokerToken{value: 1 ether}(treasury, protocolFeeDestination);
        subjectsRegistry = new SubjectsRegistryV1(jokerToken);
        vm.stopPrank();

        vm.startPrank(treasury);
        vm.deal(treasury, 10 ether);
        jokerToken.transfer(sender, 4500000 * (10 ** 8));
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

        vm.startPrank(sender);
        jokerToken.approve(computedSharePool, type(uint112).max);
        address _subjectShares = subjectsRegistry.addToRegistry(
            subject, subjectOwner, seed, name, symbol, maxSupply, halfMaxPrice, midwaySupply
        );
        subjectShares = SubjectSharesV1(payable(_subjectShares));
        vm.stopPrank();
    }

    function testCreate2Deployment(
        address caller,
        address _subject,
        address _subjectOwner,
        uint256 _seed,
        string memory _name,
        string memory _symbol,
        uint112 _maxSupply, //In 8 decimals
        uint256 _halfMaxPrice, //In 8 decimals
        uint112 _midwaySupply //In 8 decimals
    ) external {
        vm.assume(
            caller != address(0) && _halfMaxPrice > 1 * (10 ** 8) && _halfMaxPrice <= 50 * (10 ** 8)
                && _midwaySupply > 1 * (10 ** 8) && _midwaySupply < _maxSupply
        );
        vm.deal(caller, 4900000 ether);
        vm.startPrank(caller);
        jokerToken.buyTokens{value: 50000 ether}(4900000 * (10 ** 8));
        vm.stopPrank();

        bytes32 _salt = bytes32(uint256(keccak256(abi.encodePacked(block.chainid, _subject, _seed, _name, _symbol))));
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
                                        jokerToken,
                                        _subjectOwner,
                                        _name,
                                        _symbol,
                                        _maxSupply,
                                        _halfMaxPrice,
                                        _midwaySupply
                                    )
                                )
                            )
                        )
                    )
                )
            )
        );

        vm.startPrank(caller, caller);
        jokerToken.approve(computedSharePool, type(uint112).max);

        if (subjectsRegistry.bondingPair(_subject) != address(0)) {
            vm.expectRevert(abi.encodeWithSelector(SubjectRegistered.selector));
            address _subjectShares0 = subjectsRegistry.addToRegistry(
                _subject, _subjectOwner, _seed, _name, _symbol, _maxSupply, _halfMaxPrice, _midwaySupply
            );
        } else {
            address _subjectShares1 = subjectsRegistry.addToRegistry(
                _subject, _subjectOwner, _seed, _name, _symbol, _maxSupply, _halfMaxPrice, _midwaySupply
            );
            if (_subjectShares1 == address(0)) {
                vm.expectRevert(abi.encodeWithSelector(PoolCreationFailed.selector));
            } else {
                assert(
                    subjectsRegistry.bondingPair(_subject) == _subjectShares1
                        && subjectsRegistry.bondingPair(_subjectShares1) == _subject
                );
            }
        }
        vm.stopPrank();
    }

    function testRegistryFunctions(
        address caller,
        address _evilPool,
        bool _isBlacklisted,
        address _protocolFeeDestination,
        address _subjectSharePool,
        uint16 _protocolFeeRate
    ) external {
        vm.assume(caller != address(0) && _evilPool != address(0) && _subjectSharePool != address(0));
        vm.startPrank(caller);
        if (caller != defaultSender) {
            vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, caller));
            subjectsRegistry.blacklist(_evilPool, _isBlacklisted);

            vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, caller));
            subjectsRegistry.setProtocolFeeDestination(_protocolFeeDestination);

            vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, caller));
            subjectsRegistry.setProtocolFeeRate(_subjectSharePool, _protocolFeeRate);
        } else {
            if (subjectsRegistry.bondingPair(_evilPool) == address(0)) {
                vm.expectRevert(abi.encodeWithSelector(InvalidInputs.selector));
                subjectsRegistry.blacklist(_evilPool, _isBlacklisted);
            } else {
                subjectsRegistry.blacklist(_evilPool, _isBlacklisted);
                assert(subjectsRegistry.isBlacklisted(_evilPool) == _isBlacklisted);
            }

            subjectsRegistry.setProtocolFeeDestination(_protocolFeeDestination);
            assert(subjectsRegistry.protocolFeeDestination() == _protocolFeeDestination);

            if (_protocolFeeRate <= 150) {
                subjectsRegistry.setProtocolFeeRate(_subjectSharePool, _protocolFeeRate);
                assert(subjectsRegistry.protocolFeeRates(_subjectSharePool) == _protocolFeeRate);
            } else {
                vm.expectRevert(abi.encodeWithSelector(InvalidInputs.selector));
                subjectsRegistry.setProtocolFeeRate(_subjectSharePool, _protocolFeeRate);
            }
        }
        vm.stopPrank();
    }

    function testManageFunctionsOfSharePool(
        address caller,
        bool _isPoolBlacklisted,
        uint16 _newProtocolFeeRate,
        address _user,
        bool _isUserBlacklisted,
        address _newsubjectOwner
    ) external {
        vm.assume(caller != address(0));
        vm.startPrank(caller);
        if (caller == address(subjectsRegistry)) {
            subjectShares.updatePoolStatus(_isPoolBlacklisted);
            subjectShares.updateProtocolFeeRate(_newProtocolFeeRate);
            assert(
                subjectShares.isPoolBlacklisted() == _isPoolBlacklisted
                    && subjectShares.protocolFeeRate() == _newProtocolFeeRate
            );
        } else {
            vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, caller));
            subjectShares.updatePoolStatus(_isPoolBlacklisted);

            vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, caller));
            subjectShares.updateProtocolFeeRate(_newProtocolFeeRate);
        }
        vm.stopPrank();

        vm.startPrank(caller);
        if (caller == subjectOwner) {
            subjectShares.setBlacklist(_user, _isUserBlacklisted);
            subjectShares.setSubjectOwner(_newsubjectOwner);
            subjectShares.destroyMinter();
            assert(
                subjectShares.isUserBlacklisted() == _user && subjectShares.subjectOwner == _newSubjectOwner
                    && subjectShares.isMinterDestroyed == true
            );
        } else {
            vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, caller));
            subjectShares.setBlacklist(_user, _isUserBlacklisted);

            vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, caller));
            subjectShares.setSubjectOwner(_newsubjectOwner);

            vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, caller));
            subjectShares.destroyMinter();
        }
        vm.stopPrank();
    }

    function testBuyShares(address caller, uint112 amount) external {
        vm.assume(caller != address(0));

        vm.deal(caller, 4900000 ether);
        vm.startPrank(caller);
        jokerToken.buyTokens{value: 50000 ether}(4900000 * (10 ** 8));
        vm.stopPrank();
    }
}
