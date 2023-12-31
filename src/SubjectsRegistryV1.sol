//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISubjectsRegistryV1.sol";
import "./SubjectSharesV1.sol";

contract SubjectsRegistryV1 is ISubjectsRegistryV1, Ownable {
    error PoolCreationFailed();
    error SubjectRegistered();
    error InvalidInputs();

    address public protocolFeeDestination;
    mapping(address => uint16) public protocolFeeRates; //In basis points(4 decimals)
    mapping(address => bool) public isBlacklisted;
    mapping(address => address) public bondingPair;
    IERC20 public immutable JOKER_TOKEN;

    event SharePoolCreation(address subject, address subjectSharePool, string symbol);

    constructor(IERC20 _jokerToken, address _protocolFeeDestination) Ownable(msg.sender) {
        JOKER_TOKEN = _jokerToken;
        protocolFeeDestination = _protocolFeeDestination;
    }

    function addToRegistry(
        address _subject,
        address _subjectOwner,
        uint256 _seed,
        string memory _name,
        string memory _symbol,
        uint112 _maxSupply, //In 8 decimals
        uint256 _halfMaxPrice, //In 8 decimals
        uint112 _midwaySupply //In 8 decimals
    ) external returns (address) {
        if (bondingPair[_subject] != address(0)) {
            revert SubjectRegistered();
        }
        bytes32 _salt = bytes32(uint256(keccak256(abi.encodePacked(block.chainid, _subject, _seed, _name, _symbol))));

        SubjectSharesV1 newSharePool = new SubjectSharesV1{salt: _salt}(
            JOKER_TOKEN,
            _subjectOwner, 
            _name, 
            _symbol, 
            _maxSupply, 
            _halfMaxPrice, 
            _midwaySupply
            );
        address _newSharePool = address(newSharePool);
        if (_newSharePool == address(0)) {
            revert PoolCreationFailed();
        }

        protocolFeeRates[_newSharePool] = 25; // 1/6 cut of trading fees
        bondingPair[_subject] = _newSharePool;
        bondingPair[_newSharePool] = _subject;

        emit SharePoolCreation(_subject, _newSharePool, _symbol);

        return _newSharePool;
    }

    function blacklist(address _evilPool, bool _isBlacklisted) external onlyOwner {
        if (bondingPair[_evilPool] == address(0)) {
            revert InvalidInputs();
        }
        isBlacklisted[_evilPool] = _isBlacklisted;
        SubjectSharesV1(payable(_evilPool)).updatePoolStatus(true);
    }

    function setProtocolFeeDestination(address _protocolFeeDestination) external onlyOwner {
        protocolFeeDestination = _protocolFeeDestination;
    }

    //In basis points
    function setProtocolFeeRate(address _subjectSharePool, uint16 _protocolFeeRate) external onlyOwner {
        if (_protocolFeeRate > 150) {
            revert InvalidInputs();
        }
        protocolFeeRates[_subjectSharePool] = _protocolFeeRate;
        SubjectSharesV1(payable(_subjectSharePool)).updateProtocolFeeRate(_protocolFeeRate);
    }
}
