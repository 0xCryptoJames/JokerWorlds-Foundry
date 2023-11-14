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
    error AddressOrPoolBlacklisted();
    error MinterDestroyed();
    error Unauthorized();
    error PoolCreationFailed();
    error SubjectRegistered();
    error OwnableUnauthorizedAccount(address account);

    JokerToken public jokerToken;
    SubjectsRegistryV1 public subjectsRegistry;
    SubjectSharesV1 public subjectShares;

    function setUp() external {
        vm.deal(subjectOwner, 10 ether);

        jokerToken = new JokerToken{value: 1 ether}(treasury, protocolFeeDestination);
        subjectsRegistry = new SubjectsRegistryV1(jokerToken, protocolFeeDestination);

        vm.startPrank(treasury);
        vm.deal(treasury, 10 ether);
        jokerToken.transfer(subjectOwner, 4500000 * (10 ** 8));
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
            caller != address(0) && _subjectOwner != address(0) && _halfMaxPrice > 1 * (10 ** 8)
                && _halfMaxPrice <= 50 * (10 ** 8) && _midwaySupply > 1 * (10 ** 8) && _midwaySupply < _maxSupply
        );
        vm.deal(_subjectOwner, 4900000 ether);
        vm.startPrank(_subjectOwner);
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

        vm.startPrank(_subjectOwner);
        jokerToken.approve(computedSharePool, type(uint112).max);
        vm.stopPrank();

        vm.startPrank(caller);
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
        address _newSubjectOwner
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
        if (caller == subjectShares.subjectOwner()) {
            if (subjectShares.isMinterDestroyed() == true) {
                vm.expectRevert(abi.encodeWithSelector(MinterDestroyed.selector));
                subjectShares.destroyMinter();
            } else {
                subjectShares.destroyMinter();
            }
            subjectShares.setBlacklist(_user, _isUserBlacklisted);
            subjectShares.setSubjectOwner(_newSubjectOwner);

            assert(
                subjectShares.isUserBlacklisted(_user) == _isUserBlacklisted
                    && subjectShares.subjectOwner() == _newSubjectOwner && subjectShares.isMinterDestroyed() == true
            );
        } else {
            vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
            subjectShares.setBlacklist(_user, _isUserBlacklisted);

            vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
            subjectShares.setSubjectOwner(_newSubjectOwner);

            vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
            subjectShares.destroyMinter();
        }
        vm.stopPrank();
    }

    function testBuyShares(address caller, uint112 amount, uint112 amount1, bool isMinterDestroyed) external {
        vm.assume(caller != address(0) && amount > 0 && amount1 > 0 && amount <= 490000 * (10 ** 8));
        if (isMinterDestroyed) {
            vm.startPrank(subjectOwner);
            subjectShares.destroyMinter();
            vm.stopPrank();
        }

        vm.deal(caller, 4900000 ether);
        vm.startPrank(caller);
        jokerToken.buyTokens{value: 50000 ether}(4900000 * (10 ** 8));

        uint112 currentSupply = uint112(subjectShares.totalSupply());
        uint256 paymentAmount =
            subjectShares.getReserve(currentSupply + amount) - subjectShares.getReserve(currentSupply);
        (uint256 protocolFee1, uint256 subjectFee1) = subjectShares.getFees(paymentAmount);
        jokerToken.approve(address(subjectShares), type(uint112).max);
        vm.stopPrank();

        vm.startPrank(caller);
        if (subjectShares.isMinterDestroyed()) {
            vm.expectRevert(abi.encodeWithSelector(MinterDestroyed.selector));
            subjectShares.buyShares(amount);
        } else if ((currentSupply + amount) >= subjectShares.MAX_SUPPLY()) {
            vm.expectRevert(abi.encodeWithSelector(InvalidInputs.selector));
            subjectShares.buyShares(amount);
        } else if ((jokerToken.balanceOf(caller)) * (10 ** 8) < (paymentAmount + protocolFee1 + subjectFee1)) {
            vm.expectRevert(abi.encodeWithSelector(InsufficientBalance.selector));
            subjectShares.buyShares(amount);
        } else {
            uint256 preBalance = subjectShares.balanceOf(caller);
            subjectShares.buyShares(amount);
            uint256 afterBalance = subjectShares.balanceOf(caller);
            assert(uint256(amount) == afterBalance - preBalance);
        }

        vm.stopPrank();
    }

    function testSellShares(address caller, uint112 amount, uint112 amount1) external {
        vm.assume(caller != address(0) && amount > 0 && amount1 > 0 && amount1 <= amount && amount < 2000 * (10 ** 8));

        vm.deal(caller, 4900000 ether);
        vm.startPrank(caller);
        jokerToken.buyTokens{value: 50000 ether}(4900000 * (10 ** 8));

        jokerToken.approve(address(subjectShares), type(uint112).max);
        uint256 preBalance = subjectShares.balanceOf(caller);
        subjectShares.buyShares(amount);
        uint256 afterBalance = subjectShares.balanceOf(caller);
        assert(uint256(amount) == afterBalance - preBalance);

        if (amount1 > subjectShares.balanceOf(caller)) {
            vm.expectRevert(abi.encodeWithSelector(InsufficientBalance.selector));
        } else {
            uint256 paymentAmount0;
            uint256 protocolFee2;
            uint256 subjectFee2;
            {
                uint112 currentSupply = uint112(subjectShares.totalSupply());
                uint256 currentReserve = jokerToken.balanceOf(address(subjectShares)); // gas saving
                uint256 reserve0 = subjectShares.getReserve(currentSupply);
                paymentAmount0 =
                    subjectShares.getReserve(currentSupply) - subjectShares.getReserve(currentSupply - amount1);
                uint256 profitToShare = currentReserve > reserve0 ? (currentReserve - reserve0) : 0; //The total incomes distributed by the application linked to this pool
                uint256 paymentAmount1 = paymentAmount0 * profitToShare / reserve0 + paymentAmount0;

                (protocolFee2, subjectFee2) = subjectShares.getFees(paymentAmount1);
            }
            {
                uint256 preBalance1 = subjectShares.balanceOf(caller);
                uint256 preBalance2 = jokerToken.balanceOf(caller);
                subjectShares.sellShares(amount);
                uint256 afterBalance1 = subjectShares.balanceOf(caller);
                uint256 afterBalance2 = jokerToken.balanceOf(caller);
                uint256 paymentForTrade = (paymentAmount0 - protocolFee2 - subjectFee2) / (10 ** 8);

                assert(
                    uint256(amount) == (preBalance1 - afterBalance1) && (afterBalance2 - preBalance2) >= paymentForTrade
                );
            }
        }
    }

    function testPoolBlacklist(address caller, bool _isPoolBlacklisted, bool _isUserBlacklisted) external {
        vm.assume(caller != address(0));

        vm.deal(caller, 4900000 ether);
        vm.startPrank(caller);
        jokerToken.buyTokens{value: 50000 ether}(4900000 * (10 ** 8));

        jokerToken.approve(address(subjectShares), type(uint112).max);
        uint256 preBalance = subjectShares.balanceOf(caller);
        subjectShares.buyShares(100 * (10 ** 8));
        uint256 afterBalance = subjectShares.balanceOf(caller);
        assert(uint256(100 * (10 ** 8)) == afterBalance - preBalance);
        vm.stopPrank();

        if (_isPoolBlacklisted || _isUserBlacklisted) {
            vm.startPrank(subjectShares.owner());
            subjectShares.updatePoolStatus(_isPoolBlacklisted);
            vm.stopPrank();

            vm.startPrank(subjectShares.subjectOwner());
            subjectShares.setBlacklist(caller, _isUserBlacklisted);
            vm.stopPrank();

            vm.startPrank(caller);
            vm.expectRevert(abi.encodeWithSelector(AddressOrPoolBlacklisted.selector));
            subjectShares.buyShares(1 * (10 ** 8));

            vm.expectRevert(abi.encodeWithSelector(AddressOrPoolBlacklisted.selector));
            subjectShares.sellShares(1 * (10 ** 8));

            vm.expectRevert(abi.encodeWithSelector(AddressOrPoolBlacklisted.selector));
            subjectShares.transfer(BURN_ADDRESS, 1 * (10 ** 8));
            vm.stopPrank();
        }
    }
}
