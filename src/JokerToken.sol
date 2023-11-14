//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract JokerToken is Ownable, ReentrancyGuard, ERC20 {
    error PaymentFailed();
    error InvalidInputs();
    error InsufficientBalance();
    error TransferDisabled();
    error AddressBlacklisted();

    uint256 public constant HALF_MAXPRICE = 0.005 ether; // 18 decimals
    uint112 public constant MIDWAY_SUPPLY = 5000000 * (10 ** 8); // 8 decimals

    bool public isTransferEnabled = true;
    uint16 public protocolFeePercent = 50; // In basis points(4 decimals)
    address public protocolFeeDestination;
    address public treasury;
    mapping(address => bool) public blacklisted;

    event Blacklist(address indexed tokenContract, address indexed evilAddress, bool isBlacklisted);

    event JokerTokenTrade(
        address indexed tokenContract, address indexed trader, bool isBuy, uint256 amount, uint256 payment
    );

    constructor(address initialTreasury, address initialProtocolFeeDestination)
        payable
        ERC20("Joker Token", "JOKER")
        Ownable(msg.sender)
    {
        if (initialTreasury == address(0) || initialProtocolFeeDestination == address(0) || msg.value < 0.005 ether) {
            revert InvalidInputs();
        }
        protocolFeeDestination = initialProtocolFeeDestination;
        treasury = initialTreasury;
        //initialLiquidity >= _getReserve(MIDWAY_SUPPLY) - _getReserve(0);
        _mint(treasury, MIDWAY_SUPPLY); // premint for reserve
    }

    receive() external payable {
        revert PaymentFailed();
    }

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    function getReserve(uint112 supply) external pure returns (uint256) {
        return _getReserve(supply);
    }

    function setFeeDestination(address newProtocolFeeDestination) external onlyOwner {
        if (newProtocolFeeDestination == address(0)) {
            revert InvalidInputs();
        }
        protocolFeeDestination = newProtocolFeeDestination;
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) {
            revert InvalidInputs();
        }
        treasury = newTreasury;
    }

    //In basis points
    function setProtocolFeePercent(uint16 newProtocolFeePercent) external onlyOwner {
        if (newProtocolFeePercent >= 10000) {
            revert InvalidInputs();
        }
        protocolFeePercent = newProtocolFeePercent;
    }

    function blacklist(address user, bool isBlacklisted) external onlyOwner {
        blacklisted[user] = isBlacklisted;
        emit Blacklist(address(this), user, isBlacklisted);
    }

    function setTransferEnabled(bool isEnabled) external onlyOwner {
        isTransferEnabled = isEnabled;
    }

    function buyTokens(uint112 amount) external payable nonReentrant {
        if (amount == 0 || (totalSupply() + amount > type(uint112).max)) {
            revert InvalidInputs();
        }
        uint112 currentReserve = uint112(totalSupply());
        uint256 paymentAmount = _getReserve(currentReserve + amount) - _getReserve(currentReserve);
        uint256 protocolFee = paymentAmount * protocolFeePercent / 10000;

        if ((msg.value) * (10 ** 8) < paymentAmount + protocolFee) {
            revert InsufficientBalance();
        }
        (bool success,) = payable(protocolFeeDestination).call{value: protocolFee / (10 ** 8)}("");
        if (!success) {
            revert PaymentFailed();
        }
        _mint(msg.sender, amount);
        emit JokerTokenTrade(address(this), msg.sender, true, amount, msg.value);
    }

    function sellTokens(uint112 amount) external nonReentrant {
        if (amount == 0) {
            revert InvalidInputs();
        }
        if (amount > balanceOf(msg.sender)) {
            revert InsufficientBalance();
        }
        uint112 currentReserve = uint112(totalSupply());
        uint256 paymentAmount = _getReserve(currentReserve) - _getReserve(currentReserve - amount);
        uint256 protocolFee = paymentAmount * protocolFeePercent / 1 ether;
        _burn(msg.sender, amount);
        emit JokerTokenTrade(address(this), msg.sender, false, amount, paymentAmount / (10 ** 8));
        (bool success1,) = payable(protocolFeeDestination).call{value: protocolFee / (10 ** 8)}("");
        (bool success2,) = payable(msg.sender).call{value: (paymentAmount - protocolFee) / (10 ** 8)}("");
        if (!success1 || !success2) {
            revert PaymentFailed();
        }
    }

    //Sigmoid function
    function _getReserve(uint112 supply) internal pure returns (uint256) {
        uint112 supplyDiff = supply < MIDWAY_SUPPLY ? (MIDWAY_SUPPLY - supply) : (supply - MIDWAY_SUPPLY);
        uint256 reserve;
        if (supply < MIDWAY_SUPPLY) {
            reserve = HALF_MAXPRICE * (Math.sqrt(1 + (uint256(supplyDiff) ** 2)) - uint256(supplyDiff));
        } else {
            reserve = HALF_MAXPRICE * (Math.sqrt(1 + (uint256(supplyDiff) ** 2)) + uint256(supplyDiff));
        }

        return reserve;
    }

    function _update(address from, address to, uint256 amount) internal virtual override {
        if (!isTransferEnabled) {
            revert TransferDisabled();
        }
        if (blacklisted[from] || blacklisted[to]) {
            revert AddressBlacklisted();
        }
        super._update(from, to, amount);
    }
}
