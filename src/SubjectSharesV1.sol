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
    error InsufficientBalance();
    error AddressOrPoolBlacklisted();
    error Unauthorized();
    error MinterDestroyed();

    uint256 public immutable HALF_MAXPRICE; //Represents half of the maximum allowed price in 8 decimals
    uint112 public immutable MAX_SUPPLY; // In 8 decimals
    uint112 public immutable MIDWAY_SUPPLY; // Represents the supply at half max price in 8 decimals

    IERC20 public immutable JOKER_TOKEN;
    address public immutable REGISTRY;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    bool public isPoolBlacklisted;
    bool public isMinterDestroyed;
    uint16 public protocolFeeRate = 25; // 1/6 cut of trading fees and calculate in basis points (4 decimals)
    address public subjectOwner = 0x000000000000000000000000000000000000dEaD;
    mapping(address => bool) public isUserBlacklisted;

    //Set subject fee destination as the subject owner
    modifier onlySubjectOwner() {
        if (msg.sender != subjectOwner) {
            revert Unauthorized();
        }
        _;
    }

    constructor(
        IERC20 _jokerToken,
        address _subjectOwner,
        string memory _name,
        string memory _symbol,
        uint112 _maxSupply, // In 8 decimals
        uint256 _halfMaxPrice, // In 8 decimals
        uint112 _midwaySupply // In 8 decimals
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        if (_maxSupply <= _midwaySupply || _halfMaxPrice < 1 * (10 ** 8) || _midwaySupply <= 1 * (10 ** 8)) {
            revert InvalidInputs();
        }
        JOKER_TOKEN = _jokerToken;
        HALF_MAXPRICE = _halfMaxPrice;
        MAX_SUPPLY = _maxSupply;
        MIDWAY_SUPPLY = _midwaySupply;
        REGISTRY = msg.sender;
        subjectOwner = _subjectOwner;

        bool success = JOKER_TOKEN.transferFrom(subjectOwner, address(this), HALF_MAXPRICE / (10 ** 8));
        if (!success) {
            revert PaymentFailed();
        }

        _mint(BURN_ADDRESS, MIDWAY_SUPPLY); // Perminantly lock the initial payment as MINIMUM_LIQUIDITY
    }

    receive() external payable {
        revert PaymentFailed();
    }

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    function getReserve(uint112 supply) external view returns (uint256) {
        return _getReserve(supply);
    }

    function getFees(uint256 _paymentAmount) external view returns (uint256 protocolFee, uint256 subjectFee) {
        return _getFees(_paymentAmount);
    }

    function updatePoolStatus(bool _isPoolBlacklisted) external onlyOwner {
        isPoolBlacklisted = _isPoolBlacklisted;
    }

    function updateProtocolFeeRate(uint16 _newProtocolFeeRate) external onlyOwner {
        protocolFeeRate = _newProtocolFeeRate;
    }

    function setBlacklist(address _user, bool _isUserBlacklisted) external onlySubjectOwner {
        isUserBlacklisted[_user] = _isUserBlacklisted;
    }

    function setSubjectOwner(address _newsubjectOwner) external onlySubjectOwner {
        subjectOwner = _newsubjectOwner;
    }

    //Permanent function to destroy minter function, callable only once. Use with caution.
    function destroyMinter() external onlySubjectOwner {
        if (isMinterDestroyed) {
            revert MinterDestroyed();
        }
        isMinterDestroyed = true;
    }

    function buyShares(uint112 amount) public nonReentrant {
        if (isMinterDestroyed) {
            revert MinterDestroyed();
        }
        uint112 currentSupply = uint112(totalSupply());
        if (amount == 0 || (currentSupply + amount) >= MAX_SUPPLY) {
            revert InvalidInputs();
        }
        address protocolFeeDestination = ISubjectsRegistryV1(REGISTRY).protocolFeeDestination();
        uint256 paymentAmount = _getReserve(currentSupply + amount) - _getReserve(currentSupply);
        (uint256 protocolFee, uint256 subjectFee) = _getFees(paymentAmount);
        //Accounts for decimal differences in calculation
        if ((JOKER_TOKEN.balanceOf(msg.sender)) * (10 ** 8) < (paymentAmount + protocolFee + subjectFee)) {
            revert InsufficientBalance();
        }
        {
            //Scope for avoiding stack too deep errors
            bool success1 = JOKER_TOKEN.transferFrom(
                msg.sender, address(this), (paymentAmount + protocolFee + subjectFee) / (10 ** 8)
            );
            bool success2 = JOKER_TOKEN.transfer(protocolFeeDestination, protocolFee / (10 ** 8));
            bool success3 = JOKER_TOKEN.transfer(subjectOwner, subjectFee / (10 ** 8));
            if (!success1 || !success2 || !success3) {
                revert PaymentFailed();
            }
        }
        _mint(msg.sender, amount);
    }

    function sellShares(uint112 amount) public nonReentrant {
        if (amount == 0) {
            revert InvalidInputs();
        }
        if (amount > balanceOf(msg.sender)) {
            revert InsufficientBalance();
        }
        address protocolFeeDestination = ISubjectsRegistryV1(REGISTRY).protocolFeeDestination();
        uint112 currentSupply = uint112(totalSupply());
        uint256 currentReserve = JOKER_TOKEN.balanceOf(address(this)); // The pool's accumulated reserve
        uint256 paymentAmount;
        {
            //Scope for avoiding stack too deep error
            uint256 reserve0 = _getReserve(currentSupply); //Calculated theoretical reserve excluding incomes.
            uint256 paymentAmount0 = _getReserve(currentSupply) - _getReserve(currentSupply - amount);
            uint256 profitToShare = currentReserve > reserve0 ? (currentReserve - reserve0) : 0; //The total incomes distributed by the application linked to this pool
            paymentAmount = paymentAmount0 * profitToShare / reserve0 + paymentAmount0;
        }
        (uint256 protocolFee, uint256 subjectFee) = _getFees(paymentAmount);
        _burn(msg.sender, amount);
        {
            //Scope for avoiding stack too deep error
            bool success1 = JOKER_TOKEN.transfer(protocolFeeDestination, protocolFee / (10 ** 8));
            bool success2 = JOKER_TOKEN.transfer(subjectOwner, subjectFee / (10 ** 8));
            bool success3 = JOKER_TOKEN.transfer(msg.sender, (paymentAmount - protocolFee - subjectFee) / (10 ** 8));
            currentReserve = JOKER_TOKEN.balanceOf(address(this));
            if (!success1 || !success2 || !success3) {
                revert PaymentFailed();
            }
        }
    }

    function _update(address from, address to, uint256 amount) internal virtual override {
        if (amount >= type(uint112).max) {
            revert InvalidInputs();
        }
        if (isUserBlacklisted[from] || isUserBlacklisted[to] || isPoolBlacklisted) {
            revert AddressOrPoolBlacklisted();
        }
        super._update(from, to, amount);
        if (totalSupply() >= type(uint112).max) {
            revert InvalidInputs();
        }
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

    function _getFees(uint256 _paymentAmount) private view returns (uint256 protocolFee, uint256 subjectFee) {
        uint16 _protocolFeeRate = protocolFeeRate;
        protocolFee = _paymentAmount * _protocolFeeRate / 10000;
        subjectFee = _paymentAmount * (150 - _protocolFeeRate) / 10000;
        return (protocolFee, subjectFee);
    }
}
