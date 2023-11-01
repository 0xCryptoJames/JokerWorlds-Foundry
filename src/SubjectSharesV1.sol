//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/ISubjectsRegistryV1.sol";

contract SubjectSharesV1 is Ownable, ReentrancyGuard, ERC20 {
    error PaymentFailed();
    error InvalidInputs();
    error InsufficientPayment();
    error AddressBlacklisted();
    error Unauthorized();

    uint256 public immutable HALF_MAXPRICE; //Represents half of the maximum allowed price
    uint112 public immutable MAX_SUPPLY;
    uint112 public immutable MIDWAY_SUPPLY; // Represents the supply at half max price
    uint256 public immutable MINIMUM_LIQUIDITY;

    IERC20 public immutable JOKER_TOKEN;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address public immutable REGISTRY;

    bool public isPoolBlacklisted;
    uint16 public protocolFeeRate = 25; // In basis points
    mapping(address => bool) public isUserBlacklisted;
    address public subjectOwner;

    //Set subject fee destination as the subject owner
    modifier onlySubjectOwner() {
        if (msg.sender != subjectOwner) revert Unauthorized();
        _;
    }

    constructor(
        IERC20 _jokerToken,
        address _subjectOwner,
        string memory _name,
        string memory _symbol,
        uint112 _maxSupply,
        uint256 _halfMaxprice,
        uint112 _midwaySupply
    ) payable ERC20(_name, _symbol) Ownable(msg.sender) {
        if (_maxSupply <= 1 * (10 ** 18)) revert InvalidInputs();
        JOKER_TOKEN = _jokerToken;
        MAX_SUPPLY = _maxSupply;
        HALF_MAXPRICE = _halfMaxprice;
        MIDWAY_SUPPLY = _midwaySupply;
        REGISTRY = msg.sender;
        subjectOwner = _subjectOwner;

        MINIMUM_LIQUIDITY = _getReserve(1 * (10 ** 18)) - _getReserve(0);
        if (msg.value < MINIMUM_LIQUIDITY) revert InsufficientPayment();
        _mint(BURN_ADDRESS, 1 * (10 ** 18)); // Perminantly lock the first share tokens as MINIMUM_LIQUIDITY
    }

    function updatePoolStatus(bool _isPoolBlacklisted) external onlyOwner {
        isPoolBlacklisted = _isPoolBlacklisted;
    }

    function updateProtocolFeeRate(uint16 _protocolFeeRate) external onlyOwner {
        protocolFeeRate = _protocolFeeRate;
    }

    function setBlacklist(address _user, bool _isUserBlacklisted) external onlySubjectOwner {
        isUserBlacklisted[_user] = _isUserBlacklisted;
    }

    function setSubjectFeeDestination(address _subjectFeeDestination) external onlySubjectOwner {
        subjectOwner = _subjectFeeDestination;
    }

    function buyShares(uint112 amount) public payable nonReentrant {
        uint112 currentSupply = uint112(totalSupply());
        if (amount == 0 || (currentSupply + amount) >= MAX_SUPPLY) revert InvalidInputs();
        address protocolFeeDestination = ISubjectsRegistryV1(REGISTRY).protocolFeeDestination();
        uint256 paymentAmount = _getReserve(currentSupply + amount) - _getReserve(currentSupply);
        (uint256 protocolFee, uint256 subjectFee) = _getFees(paymentAmount);
        if (JOKER_TOKEN.balanceOf(msg.sender) < (paymentAmount + protocolFee + subjectFee)) {
            revert InsufficientPayment();
        }
        {
            //Scope for avoiding stack too deep errors
            bool success1 = JOKER_TOKEN.transfer(protocolFeeDestination, protocolFee);
            bool success2 = JOKER_TOKEN.transfer(subjectOwner, subjectFee);
            if (!success1 || !success2) revert PaymentFailed();
        }
        _mint(msg.sender, amount);
    }

    function sellShares(uint112 amount) public payable nonReentrant {
        if (amount == 0) revert InvalidInputs();
        if (amount > balanceOf(msg.sender)) revert InsufficientPayment();
        address protocolFeeDestination = ISubjectsRegistryV1(REGISTRY).protocolFeeDestination();
        uint112 currentSupply = uint112(totalSupply());
        uint256 currentReserve = JOKER_TOKEN.balanceOf(address(this)); // gas saving
        uint256 paymentAmount;
        {
            //Scope for avoiding stack too deep errors
            uint256 reserve0 = _getReserve(currentSupply);
            uint256 paymentAmount0 = _getReserve(currentSupply - amount) - _getReserve(currentSupply);
            uint256 profitToShare = currentReserve > reserve0 ? (currentReserve - reserve0) : 0; //The total incomes distributed by the application linked to this pool
            paymentAmount = paymentAmount0 * profitToShare / reserve0 + paymentAmount0;
        }
        (uint256 protocolFee, uint256 subjectFee) = _getFees(paymentAmount);
        _burn(msg.sender, amount);
        {
            //Scope for avoiding stack too deep errors
            bool success1 = JOKER_TOKEN.transfer(protocolFeeDestination, protocolFee);
            bool success2 = JOKER_TOKEN.transfer(subjectOwner, subjectFee);
            bool success3 = JOKER_TOKEN.transfer(msg.sender, (paymentAmount - protocolFee - subjectFee));
            currentReserve = JOKER_TOKEN.balanceOf(address(this));
            if (!success1 || !success2 || !success3 || (currentReserve < MINIMUM_LIQUIDITY)) revert PaymentFailed();
        }
    }

    function _update(address from, address to, uint256 amount) internal virtual override {
        if (amount >= type(uint112).max) revert InvalidInputs();
        if (isUserBlacklisted[from] || isUserBlacklisted[to] || isPoolBlacklisted) revert AddressBlacklisted();
        super._update(from, to, amount);
        if (totalSupply() >= type(uint112).max) revert InvalidInputs();
    }

    function _getReserve(uint112 supply) private view returns (uint256) {
        uint112 supplyDiff = supply < MIDWAY_SUPPLY ? (MIDWAY_SUPPLY - supply) : (supply - MIDWAY_SUPPLY);
        uint256 reserve;
        if (supply < MIDWAY_SUPPLY) {
            reserve = HALF_MAXPRICE * (Math.sqrt(1 + (uint256(supplyDiff) ** 2)) - uint256(supplyDiff));
        } else {
            reserve = HALF_MAXPRICE * (Math.sqrt(1 + (uint256(supplyDiff) ** 2)) + uint256(supplyDiff));
        }

        return reserve;
    }

    function _getFees(uint256 _paymentAmount) private view returns (uint256, uint256) {
        uint16 _protocolFeeRate = protocolFeeRate;
        return (_paymentAmount * _protocolFeeRate / 10000, _paymentAmount * (150 - _protocolFeeRate) / 10000);
    }
}
