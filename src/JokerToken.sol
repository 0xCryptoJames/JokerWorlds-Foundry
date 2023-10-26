//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract JokerToken is Ownable, ReentrancyGuard, ERC20 {
    error PaymentFailed();
    error InvalidInputs();
    error InsufficientPayment();
    error TransferDisabled();
    error AddressBlacklisted();

    uint256 public constant HALF_MAXPRICE = 0.005 ether;
    uint112 public constant MIDWAY_SUPPLY = 5000000 * (10 ** 18);

    bool public isTransferEnabled = true;
    uint16 public protocolFeePercent = 50; // In basis points
    address public protocolFeeDestination;
    address public treasury;
    mapping(address => bool) public isBlacklisted;

    event Blacklist(address _evilAddress, bool _isBlacklisted);
    event JokerTokenTrade(address trader, bool isBuy, uint256 amount, uint256 payment);

    constructor(address _treasury, address _protocolFeeDestination)
        payable
        ERC20("Joker Token", "JOKER")
        Ownable(msg.sender)
    {
        protocolFeeDestination = _protocolFeeDestination;
        treasury = _treasury;
        uint256 initialLiquidity = getReserve(MIDWAY_SUPPLY) - getReserve(0);
        if (msg.value < initialLiquidity) revert InsufficientPayment();
        _mint(treasury, MIDWAY_SUPPLY); // premint for reserve
    }

    //Sigmoid function
    function getReserve(uint112 supply) private pure returns (uint256) {
        uint112 supplyDiff = supply < MIDWAY_SUPPLY ? (MIDWAY_SUPPLY - supply) : (supply - MIDWAY_SUPPLY);
        uint256 reserve;
        if (supply < MIDWAY_SUPPLY) {
            reserve = HALF_MAXPRICE * (Math.sqrt(1 + (uint256(supplyDiff) * uint256(supplyDiff))) - uint256(supplyDiff));
        } else {
            reserve = HALF_MAXPRICE * (Math.sqrt(1 + (uint256(supplyDiff) * uint256(supplyDiff))) + uint256(supplyDiff));
        }

        return reserve;
    }

    function setFeeDestination(address _feeDestination) public onlyOwner {
        protocolFeeDestination = _feeDestination;
    }

    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }
    //In basis points

    function setProtocolFeePercent(uint16 _feePercent) public onlyOwner {
        if (_feePercent >= 10000) revert InvalidInputs();
        protocolFeePercent = _feePercent;
    }

    function blacklist(address user, bool _isBlacklisted) public onlyOwner {
        isBlacklisted[user] = _isBlacklisted;
        emit Blacklist(user, _isBlacklisted);
    }

    function setTransferEnabled(bool _isEnabled) public onlyOwner {
        isTransferEnabled = _isEnabled;
    }

    function buyTokens(uint256 amount) public payable nonReentrant {
        if (amount == 0) revert InvalidInputs();
        uint112 currentReserve = uint112(totalSupply());
        uint256 paymentAmount = getReserve(currentReserve + uint112(amount)) - getReserve(currentReserve);
        uint256 protocolFee = paymentAmount * protocolFeePercent / 10000;
        if (msg.value < paymentAmount + protocolFee) revert InsufficientPayment();
        (bool success,) = protocolFeeDestination.call{value: protocolFee}("");
        if (!success) revert PaymentFailed();
        _mint(msg.sender, amount);
        emit JokerTokenTrade(msg.sender, true, amount, msg.value);
    }

    function sellTokens(uint256 amount) public payable nonReentrant {
        if (amount == 0) revert InvalidInputs();
        if (amount > balanceOf(msg.sender)) revert InsufficientPayment();
        uint112 currentReserve = uint112(totalSupply());
        uint256 paymentAmount = getReserve(currentReserve) - getReserve(currentReserve - uint112(amount));
        uint256 protocolFee = paymentAmount * protocolFeePercent / 1 ether;
        _burn(msg.sender, amount);
        (bool success1,) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2,) = (msg.sender).call{value: paymentAmount - protocolFee}("");
        if (!success1 || !success2) revert PaymentFailed();
        emit JokerTokenTrade(msg.sender, false, amount, paymentAmount);
    }

    function _update(address from, address to, uint256 amount) internal virtual override {
        if (!isTransferEnabled) revert TransferDisabled();
        if (isBlacklisted[from] || isBlacklisted[to]) revert AddressBlacklisted();
        super._update(from, to, amount);
    }
}
